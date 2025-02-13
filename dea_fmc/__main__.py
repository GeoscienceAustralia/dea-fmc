# Import modules
import logging
import os
import sys
import click
import datacube
import joblib
import numpy as np
import xarray as xr
import boto3  # for interacting with AWS SQS
import warnings
import datetime
import json
import io
from datetime import datetime as dt
from pathlib import Path

from datacube.utils.cog import write_cog
from dea_tools.classification import sklearn_flatten, sklearn_unflatten
from odc.algo import mask_cleanup

import dea_fmc.__version__
from dea_fmc import fmc_io, helper

# Import eodatasets3 and related modules for metadata generation
from eodatasets3.assemble import DatasetAssembler, serialise
import eodatasets3.stac as eo3stac

# Configure logging
logging.getLogger("botocore.credentials").setLevel(logging.WARNING)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
logger = logging.getLogger(__name__)


def logging_setup():
    """Set up logging for all modules except sqlalchemy and boto."""
    loggers = [
        logging.getLogger(name)
        for name in logging.root.manager.loggerDict
        if not name.startswith("sqlalchemy") and not name.startswith("boto")
    ]
    stdout_hdlr = logging.StreamHandler(sys.stdout)
    for logger_obj in loggers:
        logger_obj.addHandler(stdout_hdlr)
        logger_obj.propagate = False


def classify_fmc(data, model):
    """
    Perform FMC classification using a pre-trained model.
    """
    # Calculate NDVI and NDII
    data["ndii"] = (data.nbart_nir_1 - data.nbart_swir_2) / (
        data.nbart_nir_1 + data.nbart_swir_2
    )
    data["ndvi"] = (data.nbart_nir_1 - data.nbart_red) / (
        data.nbart_nir_1 + data.nbart_red
    )

    # Reorder variables to match model expectations
    bands_order = [
        "ndvi",
        "ndii",
        "nbart_blue",
        "nbart_green",
        "nbart_red",
        "nbart_red_edge_1",
        "nbart_red_edge_2",
        "nbart_red_edge_3",
        "nbart_nir_1",
        "nbart_nir_2",
        "nbart_swir_2",
        "nbart_swir_3",
    ]
    data_neworder = data[bands_order]

    # Flatten the data for classification
    data_flat = sklearn_flatten(data_neworder)
    data_flat = np.where(np.isinf(data_flat), -999, data_flat)  # Replace inf

    out_class = model.predict(data_flat)
    returned_result = sklearn_unflatten(out_class, data).transpose()

    # Create the output dataset with one measurement: LFMC
    dataset_result = xr.Dataset(
        {"LFMC": returned_result}, coords=data.coords, attrs=data.attrs
    )
    return dataset_result


def add_fmc_metadata_files(dataset, local_tif, product_name, product_version, region_code, acquisition_date):
    """
    Generate extended metadata for FMC using eodatasets3,
    then convert to both ODC and STAC formats and upload them.
    """
    # Initialize the DatasetAssembler using DEA C3 naming conventions
    dataset_assembler = DatasetAssembler(
        naming_conventions="dea_c3",
        dataset_location=Path(f"https://explorer.dea.ga.gov.au/product/{product_name}"),
        allow_absolute_paths=True,
    )

    # Suppress inheritable property warnings
    warnings.simplefilter(action="ignore", category=UserWarning)

    # Extract the source dataset document from the datacube dataset
    source_datasetdoc = serialise.from_doc(dataset.metadata_doc, skip_validation=True)
    dataset_assembler.add_source_dataset(
        source_datasetdoc,
        classifier="fmc",  # use a classifier specific to FMC
        auto_inherit_properties=True,
        inherit_geometry=False,
        inherit_skip_properties=[],  # adjust as needed
    )

    # Extract platform/instrument details from the source
    platforms = []
    instruments = []
    if "eo:platform" in source_datasetdoc.properties:
        platforms.append(source_datasetdoc.properties["eo:platform"])
    if "eo:instrument" in source_datasetdoc.properties:
        instruments.append(source_datasetdoc.properties["eo:instrument"])
    dataset_assembler.platform = ",".join(sorted(set(platforms)))
    dataset_assembler.instrument = "_".join(sorted(set(instruments)))

    # Set geometry if available (here we use the dataset’s extent if present)
    if hasattr(dataset, "extent"):
        dataset_assembler.geometry = dataset.extent
    # Otherwise, you might extract geometry from your processing (e.g. from a geobox)

    # Set the datetime and period properties (using acquisition_date for both start and end)
    dt_obj = dt.strptime(acquisition_date, "%Y-%m-%d")
    dataset_assembler.datetime = dt_obj
    dataset_assembler.properties["dtr:start_datetime"] = dt_obj.isoformat()
    dataset_assembler.properties["dtr:end_datetime"] = dt_obj.isoformat()

    # Set product details
    dataset_assembler.product_name = product_name
    dataset_assembler.dataset_version = product_version
    dataset_assembler.region_code = region_code
    dataset_assembler.properties["odc:file_format"] = "COG"
    dataset_assembler.properties["odc:producer"] = "DEA"
    dataset_assembler.properties["odc:product_family"] = "fmc"

    # Restore warnings
    warnings.filterwarnings("default")

    # Record the processing time
    dataset_assembler.processed = dt.utcnow()

    # For FMC, assume one band ("LFMC") – note the measurement filename is the GeoTIFF we generated
    dataset_assembler.note_measurement(
        "fmc",
        local_tif,
        expand_valid_data=False,
        # Optionally include grid information if available:
        # grid=GridSpec(...),
        nodata=-999,
    )

    # Extend user metadata (e.g. input product names)
    dataset_assembler.extend_user_metadata("input-products", ["ga_s2am_ard_3", "ga_s2bm_ard_3", "ga_s2cm_ard_3"])

    # Set accessories for metadata processor and thumbnail
    processor_filename = f"{product_name}_{region_code}_{acquisition_date}_processor.txt"
    thumbnail_filename = f"{product_name}_{region_code}_{acquisition_date}_thumbnail.jpg"
    dataset_assembler._accessories["metadata:processor"] = processor_filename
    dataset_assembler._accessories["thumbnail"] = thumbnail_filename

    # Convert the assembled metadata to an ODC dataset document
    meta = dataset_assembler.to_dataset_doc()

    # Define local filenames for the STAC and ODC metadata
    local_stac_metadata_path = f"{product_name}_{region_code}_{acquisition_date}.stac.json"
    local_odc_metadata_path = f"{product_name}_{region_code}_{acquisition_date}.odc.yaml"

    # Convert to STAC metadata using eo3stac – adjust parameters as needed
    stac_meta = eo3stac.to_stac_item(
        dataset=meta,
        stac_item_destination_url=local_stac_metadata_path,
        dataset_location=str(Path(local_tif).parent),
        odc_dataset_metadata_url=local_odc_metadata_path,
        explorer_base_url=f"https://explorer.dea.ga.gov.au/product/{product_name}",
    )
    stac_meta_str = json.dumps(stac_meta, indent=4)
    with open(local_stac_metadata_path, "w") as json_file:
        json_file.write(stac_meta_str)
    logger.info("Upload STAC metadata to %s", local_stac_metadata_path)
    fmc_io.upload_object_to_s3(local_stac_metadata_path, local_stac_metadata_path)

    # Serialize ODC metadata to YAML and write to file
    meta_stream = io.StringIO()
    serialise.to_stream(meta_stream, meta)
    odc_meta_str = meta_stream.getvalue()
    with open(local_odc_metadata_path, "w") as yml_file:
        yml_file.write(odc_meta_str)
    logger.info("Upload ODC metadata to %s", local_odc_metadata_path)
    fmc_io.upload_object_to_s3(local_odc_metadata_path, local_odc_metadata_path)

    # Generate a thumbnail preview using eodatasets3 (replicate LFMC across RGB)
    dataset_assembler.write_thumbnail(red="fmc", green="fmc", blue="fmc")
    # Assuming the thumbnail is saved as defined in the accessories:
    fmc_io.upload_object_to_s3(thumbnail_filename, thumbnail_filename)


def process_dataset(dataset_uuid, process_cfg_url, overwrite):
    """
    Process FMC for a given dataset UUID and configuration.
    """
    logging_setup()

    # Initialize Datacube instance
    dc = datacube.Datacube(
        app="fmc_processing",
        config={
            "db_hostname": os.getenv("ODC_DB_HOSTNAME"),
            "db_password": os.getenv("ODC_DB_PASSWORD"),
            "db_username": os.getenv("ODC_DB_USERNAME"),
            "db_port": 5432,
            "db_database": os.getenv("ODC_DB_DATABASE"),
        },
    )

    os.environ["AWS_NO_SIGN_REQUEST"] = "Yes"

    # Load process configuration
    process_cfg = helper.load_yaml_remote(process_cfg_url)
    measurements_list = process_cfg["input_products"]["input_bands"]
    output_folder = process_cfg["output_folder"]
    model_url = process_cfg["model_path"]
    product_name = process_cfg["product"]["name"]
    product_version = str(process_cfg["product"]["version"]).replace(".", "-")

    # Download the pre-trained model
    model_path = "RF_AllBands_noLC_DEA_labeless.joblib"
    helper.download_file_from_s3_public(model_url, model_path)
    model = joblib.load(model_path)

    # Load the dataset from Datacube
    dataset = dc.index.datasets.get(dataset_uuid)

    # Define output file details using dataset metadata
    region_code = dataset.metadata.fields["region_code"]
    acquisition_date = dataset.metadata.fields["time"][0].date().strftime("%Y-%m-%d")
    local_tif = f"{product_name}_{region_code}_{acquisition_date}_fmc.tif"

    s3_folder = (
        f"{output_folder}/{product_name}/{product_version}/{region_code[:2]}/{region_code[2:]}/"
        + acquisition_date.replace("-", "/")
    )
    s3_file_uri = f"{s3_folder}/{local_tif}"

    # Skip processing if output exists and overwrite is False
    if not overwrite and helper.check_s3_file_exists(s3_file_uri):
        logger.info(f"S3 object {s3_file_uri} already exists and overwrite is False. Skipping processing.")
        return

    # Load the dataset with specified measurements
    df = dc.load(
        datasets=[dataset],
        measurements=measurements_list,
        resolution=(-20, 20),
        resampling={"*": "bilinear"},
        output_crs="EPSG:3577",
    )

    # Create masks and cleanup
    cloud_mask = (df.oa_fmask == 2) | (df.oa_fmask == 3)
    water_mask = (df.oa_fmask == 5) | (df.oa_fmask == 0) | (df.oa_nbart_contiguity == 0)
    better_cloud_mask = mask_cleanup(mask=cloud_mask, mask_filters=[("opening", 1), ("dilation", 3)])
    df = df.drop_vars(["oa_fmask", "oa_nbart_contiguity"])

    # Perform FMC classification
    fmc_data = classify_fmc(df, model)
    masked_data = fmc_data.where(~better_cloud_mask & ~water_mask)
    masked_data = masked_data.where(masked_data >= 0, -999).astype("int16")

    # Save result as a Cloud Optimized GeoTIFF (COG)
    write_cog(masked_data.LFMC, fname=local_tif, overwrite=True, nodata=-999)
    logger.info(f"Result saved as: {local_tif}")

    helper.get_and_set_aws_credentials()
    fmc_io.upload_object_to_s3(local_tif, s3_file_uri)
    logger.info(f"Uploaded result to: {s3_file_uri}")

    # Generate extended metadata (ODC and STAC) and a thumbnail
    add_fmc_metadata_files(dataset, local_tif, product_name, product_version, region_code, acquisition_date)


@click.group()
@click.version_option(version=dea_fmc.__version__)
def main():
    """Run dea-fmc."""


@main.command(no_args_is_help=True)
@click.option("--dataset-uuid", "-d", type=str, required=True, help="Dataset UUID to process.")
@click.option("--process-cfg-url", "-p", type=str, required=True, help="URL to FMC process configuration file in YAML format.")
@click.option("--overwrite/--no-overwrite", default=False, help="Rerun scenes that have already been processed.")
def fmc_processing(dataset_uuid, process_cfg_url, overwrite):
    """Process FMC for a given dataset UUID and configuration."""
    process_dataset(dataset_uuid, process_cfg_url, overwrite)


@main.command()
@click.option("--dataset-uuid", "-d", type=str, required=True, help="Dataset UUID to submit to AWS SQS.")
@click.option("--queue-url", "-q", type=str, required=True, help="AWS SQS Queue URL to submit the message to.")
def submit_message(dataset_uuid, queue_url):
    """Submit a dataset UUID as a message to AWS SQS."""
    sqs = boto3.client("sqs")
    response = sqs.send_message(QueueUrl=queue_url, MessageBody=dataset_uuid)
    click.echo(f"Message submitted to SQS with MessageId: {response.get('MessageId')}")


@main.command()
@click.option("--queue-url", "-q", type=str, required=True, help="AWS SQS Queue URL to read messages from.")
@click.option("--process-cfg-url", "-p", type=str, required=True, help="URL to FMC process configuration file in YAML format.")
@click.option("--overwrite/--no-overwrite", default=True, help="Rerun scenes that have already been processed.")
def fmc_processing_with_sqs(queue_url, process_cfg_url, overwrite):
    """
    Continuously load messages from AWS SQS and process each dataset using FMC classification.
    Exits after 10 consecutive empty polls.
    """
    sqs = boto3.client("sqs")
    no_message_count = 0

    while True:
        response = sqs.receive_message(QueueUrl=queue_url, MaxNumberOfMessages=10, WaitTimeSeconds=10)
        messages = response.get("Messages", [])
        if not messages:
            no_message_count += 1
            click.echo(f"No messages found in the queue. Attempt {no_message_count} of 10.")
            if no_message_count >= 10:
                click.echo("No messages after 10 attempts. Exiting.")
                break
            continue

        no_message_count = 0
        for message in messages:
            dataset_uuid = message["Body"]
            click.echo(f"Processing dataset UUID: {dataset_uuid}")
            try:
                process_dataset(dataset_uuid, process_cfg_url, overwrite)
                sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=message["ReceiptHandle"])
                click.echo(f"Processed and deleted message for dataset UUID: {dataset_uuid}")
            except Exception as e:
                click.echo(f"Error processing dataset UUID {dataset_uuid}: {e}")

    click.echo("Finished processing messages from SQS.")


if __name__ == "__main__":
    main()
