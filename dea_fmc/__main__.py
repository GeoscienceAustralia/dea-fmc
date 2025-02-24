"""
Cleaned version of the FMC processing code.
"""

import io
import json
import logging
import os
import sys
import warnings
from datetime import datetime as dt
from pathlib import Path

import boto3
import click
import datacube
import eodatasets3.stac as eo3stac
import joblib
import matplotlib.pyplot as plt
import numpy as np
import xarray as xr
from datacube.utils.cog import write_cog
from dea_tools.classification import sklearn_flatten, sklearn_unflatten
from eodatasets3.assemble import DatasetAssembler, serialise
from eodatasets3.images import GridSpec
from matplotlib.colors import LinearSegmentedColormap
from odc.algo import mask_cleanup
from rasterio.crs import CRS

import dea_fmc.__version__
from dea_fmc import fmc_io, helper

# Configure logging
logging.getLogger("botocore.credentials").setLevel(logging.WARNING)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
logger = logging.getLogger(__name__)


def logging_setup() -> None:
    """
    Set up logging for all modules except those starting with 'sqlalchemy' or 'boto'.
    """
    loggers = [
        logging.getLogger(name)
        for name in logging.root.manager.loggerDict
        if not name.startswith("sqlalchemy") and not name.startswith("boto")
    ]
    stdout_hdlr = logging.StreamHandler(sys.stdout)
    for log in loggers:
        log.addHandler(stdout_hdlr)
        log.propagate = False


def classify_fmc(data: xr.Dataset, model) -> xr.Dataset:
    """
    Perform FMC classification using a pre-trained model.

    Calculates NDVI and NDII, reorders bands to match model expectations,
    flattens the data for prediction, and returns a Dataset with a measurement 'fmc'.
    """
    # Calculate NDII and NDVI
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

    # Flatten the data and replace any infinities with nodata (-999)
    data_flat = sklearn_flatten(data_neworder)
    data_flat = np.where(np.isinf(data_flat), -999, data_flat)

    out_class = model.predict(data_flat)
    returned_result = sklearn_unflatten(out_class, data).transpose()

    # Create the output Dataset with one measurement: fmc
    dataset_result = xr.Dataset(
        {"fmc": returned_result}, coords=data.coords, attrs=data.attrs
    )
    return dataset_result


def add_fmc_metadata_files(
    ard_dataset: xr.Dataset,
    dataset: datacube.model.Dataset,
    local_tif: str,
    product_name: str,
    product_version: str,
    region_code: str,
    acquisition_date: str,
    local_thumbnail_path: str,
    s3_folder: str,
) -> None:
    """
    Generate extended metadata for FMC using eodatasets3, convert to both ODC and STAC formats,
    and upload them (along with the thumbnail) to S3. This implementation follows the same workflow
    as the Burn Cube add_metadata_files method.
    """
    # Create a base title for naming outputs
    title = f"{product_name}_{product_version}_{region_code}_{acquisition_date}"

    # Initialize the DatasetAssembler using DEA C3 naming conventions
    dataset_assembler = DatasetAssembler(
        naming_conventions="dea_c3",
        dataset_location=Path(f"https://explorer.dea.ga.gov.au/product/{product_name}"),
        allow_absolute_paths=True,
    )

    # Suppress inheritable property warnings (as in Burn Cube)
    warnings.simplefilter(action="ignore", category=UserWarning)

    # Extract the source dataset document from the datacube metadata and add it
    source_datasetdoc = serialise.from_doc(dataset.metadata_doc, skip_validation=True)
    dataset_assembler.add_source_dataset(
        source_datasetdoc,
        classifier="ard",  # FMC-specific classifier
        auto_inherit_properties=True,
        inherit_geometry=True,
        inherit_skip_properties=[],  # Adjust if necessary
    )

    # Extract platform and instrument details from the source document
    platforms = []
    instruments = []
    if "eo:platform" in source_datasetdoc.properties:
        platforms.append(source_datasetdoc.properties["eo:platform"])
    if "eo:instrument" in source_datasetdoc.properties:
        instruments.append(source_datasetdoc.properties["eo:instrument"])
    dataset_assembler.platform = ",".join(sorted(set(platforms)))
    dataset_assembler.instrument = "_".join(sorted(set(instruments)))

    # use geometry from input dataset
    dataset_assembler.geometry = ard_dataset.geobox.extent.geom

    # Parse the acquisition date and set datetime properties
    dt_obj = dt.strptime(acquisition_date, "%Y-%m-%d")
    dataset_assembler.datetime = dt_obj
    dataset_assembler.properties["dtr:start_datetime"] = dt_obj.isoformat()
    dataset_assembler.properties["dtr:end_datetime"] = dt_obj.isoformat()

    # Set product details
    dataset_assembler.product_name = product_name
    dataset_assembler.dataset_version = product_version
    dataset_assembler.region_code = region_code
    dataset_assembler.properties["title"] = title
    dataset_assembler.properties["odc:file_format"] = "GeoTIFF"
    dataset_assembler.properties["odc:producer"] = "ga.gov.au"
    dataset_assembler.properties["odc:product_family"] = "fmc"
    dataset_assembler.maturity = "final"
    dataset_assembler.collection_number = 3

    # Restore warning settings
    warnings.filterwarnings("default")

    # Record processing time
    dataset_assembler.processed = dt.utcnow()
    
    # Add measurement note (here we assume one band named "fmc")
    dataset_assembler.note_measurement(
        "fmc",
        local_tif,
        expand_valid_data=False,
        grid=GridSpec(
            shape=ard_dataset.geobox.shape,
            transform=ard_dataset.geobox.transform,
            crs=CRS.from_epsg(ard_dataset.geobox.crs.to_epsg()),
        ),
        nodata=-999,
    )

    # Extend user metadata (e.g. input product names)
    dataset_assembler.extend_user_metadata(
        "input-products", ["ga_s2am_ard_3", "ga_s2bm_ard_3", "ga_s2cm_ard_3"]
    )

    # Set accessories for metadata processor and thumbnail
    # processor_filename = f"{title}_processor.txt"
    thumbnail_filename = f"{title}_thumbnail.jpg"
    # dataset_assembler._accessories["metadata:processor"] = processor_filename
    dataset_assembler._accessories["thumbnail"] = thumbnail_filename

    # Convert the assembled metadata to an ODC dataset document
    meta = dataset_assembler.to_dataset_doc()

    # Define local filenames for the STAC and ODC metadata files
    local_stac_metadata_path = f"{title}.stac.json"
    local_odc_metadata_path = f"{title}.odc.yaml"

    s3_stac_metadata_path = f"{s3_folder}/{local_stac_metadata_path}"
    s3_odc_metadata_path = f"{s3_folder}/{local_odc_metadata_path}"
    s3_tif_path = f"{s3_folder}/{local_tif}"
    s3_thumbnail_path = f"{s3_folder}/{thumbnail_filename}"

    # Convert to STAC metadata using eo3stac (similar to Burn Cube)
    stac_meta = eo3stac.to_stac_item(
        dataset=meta,
        stac_item_destination_url=s3_stac_metadata_path,
        dataset_location=s3_folder,
        odc_dataset_metadata_url=s3_odc_metadata_path,
        explorer_base_url=f"https://explorer.dea.ga.gov.au/product/{product_name}",
    )

    # manually fix geotiff path
    stac_meta["assets"]["fmc"]["href"] = s3_tif_path
    stac_meta["assets"]["thumbnail"]["href"] = s3_thumbnail_path

    # Write and upload STAC metadata file
    with open(local_stac_metadata_path, "w") as json_file:
        json.dump(stac_meta, json_file, indent=4)
    
    logger.info("Upload STAC metadata to %s", s3_stac_metadata_path)
    fmc_io.upload_object_to_s3(
        local_stac_metadata_path, s3_stac_metadata_path
    )

    # Serialize ODC metadata to YAML and write to file
    meta_stream = io.StringIO()
    serialise.to_stream(meta_stream, meta)
    with open(local_odc_metadata_path, "w") as yml_file:
        yml_file.write(meta_stream.getvalue())

    logger.info("Upload ODC metadata to %s", s3_odc_metadata_path)
    fmc_io.upload_object_to_s3(
        local_odc_metadata_path, s3_odc_metadata_path
    )

    # we already has the thumbail generate before
    # Upload the generated thumbnail (assumed to be at local_thumbnail_path)
    s3_thumbnail_path = f"{s3_folder}/{thumbnail_filename}"
    logger.info("Upload Thumbnail file to %s", s3_thumbnail_path)
    fmc_io.upload_object_to_s3(
        local_thumbnail_path, s3_thumbnail_path
    )

    return local_thumbnail_path, local_odc_metadata_path, local_stac_metadata_path


def generate_thumbnail(masked_data: xr.Dataset) -> str:
    """
    Generate a thumbnail image from masked data using a custom colormap.

    Returns:
        The local file path to the generated thumbnail image.
    """

    # Assume FMC_data, better_cloud_mask, and water_mask are already defined
    # Define the custom colormap
    colours = [(0.87, 0, 0), (1, 1, 0.73), (0.165, 0.615, 0.957)]
    cmap = LinearSegmentedColormap.from_list("fmc", colours, N=256)

    # If your data has a singleton 'time' dimension, squeeze it
    data_to_plot = masked_data.fmc.squeeze()

    # Get the dimensions of the data
    height, width = data_to_plot.shape

    # Choose a DPI (dots per inch)
    dpi = 100

    # Calculate figure size in inches so that the saved image has the correct resolution
    _, ax = plt.subplots(figsize=(width / dpi, height / dpi), dpi=dpi)

    # Display the image without interpolation to preserve pixel resolution
    ax.imshow(data_to_plot, cmap=cmap, interpolation="none")

    # Remove axes and extra whitespace
    ax.axis("off")
    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)

    local_thumbnail_path = "thumbnail_image.jpg"

    # Save the figure, ensuring the output matches the input resolution
    plt.savefig(
        local_thumbnail_path, dpi=dpi, bbox_inches="tight", pad_inches=0, format="jpg"
    )
    plt.close()

    return local_thumbnail_path


def process_dataset(dataset_uuid: str, process_cfg_url: str, overwrite: bool) -> None:
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
    product_version = str(process_cfg["product"]["version"]).replace(".", "-")

    # Load the dataset from Datacube
    dataset = dc.index.datasets.get(dataset_uuid)
    
    if dataset.product.name == "ga_s2am_ard_3":
        product_name = f"ga_s2am_fmc"
    elif dataset.product.name == "ga_s2bm_ard_3":
        product_name = f"ga_s2bm_fmc"
    elif dataset.product.name == "ga_s2cm_ard_3":
        product_name = f"ga_s2cm_fmc"
    else:
        logger.info(
            "Unknown platform %s Skipping processing.",
            dataset.product.name,
        )
        sys.exit(0)

    # Download and load the pre-trained model
    model_path = "RF_AllBands_noLC_DEA_labeless.joblib"
    helper.download_file_from_s3_public(model_url, model_path)
    model = joblib.load(model_path)

    # Define output file details using dataset metadata
    region_code = dataset.metadata.fields["region_code"]
    acquisition_date = dataset.metadata.fields["time"][0].date().strftime("%Y-%m-%d")
    local_tif = f"{product_name}_{product_version}_{region_code}_{acquisition_date}_final_fmc.tif"
    s3_folder = (
        f"{output_folder}/{product_name}/{product_version}/{region_code[:2]}/{region_code[2:]}/"
        + acquisition_date.replace("-", "/")
    )
    s3_file_uri = f"{s3_folder}/{local_tif}"

    # Skip processing if output exists and overwrite is False
    if not overwrite and helper.check_s3_file_exists(s3_file_uri):
        logger.info(
            "S3 object %s already exists and overwrite is False. Skipping processing.",
            s3_file_uri,
        )
        sys.exit(0)

    # Load the dataset with specified measurements
    df = dc.load(
        datasets=[dataset],
        measurements=measurements_list,
        resolution=(-20, 20),
        resampling={"*": "bilinear"},
        output_crs="EPSG:3577",
    )

    # Create masks: cloud and water masks based on fmask and contiguity
    cloud_mask = (df.oa_fmask == 2) | (df.oa_fmask == 3)
    water_mask = (df.oa_fmask == 5) | (df.oa_fmask == 0) | (df.oa_nbart_contiguity == 0)
    better_cloud_mask = mask_cleanup(
        mask=cloud_mask, mask_filters=[("opening", 1), ("dilation", 3)]
    )
    df = df.drop_vars(["oa_fmask", "oa_nbart_contiguity"])

    # Perform FMC classification
    fmc_data = classify_fmc(df, model)
    masked_data = fmc_data.where(~better_cloud_mask & ~water_mask)

    # Generate thumbnail before applying no-data control
    local_thumbnail_path = generate_thumbnail(masked_data)

    # Set nodata values (-999) for pixels below zero and cast to int16
    masked_data = masked_data.where(masked_data >= 0, -999).astype("int16")

    # Save result as a Cloud Optimized GeoTIFF (COG)
    write_cog(masked_data.fmc, fname=local_tif, overwrite=True, nodata=-999)
    logger.info("Result saved as: %s", local_tif)

    helper.get_and_set_aws_credentials()
    fmc_io.upload_object_to_s3(local_tif, s3_file_uri)
    logger.info("Uploaded result to: %s", s3_file_uri)

    # Generate extended metadata (ODC and STAC) and upload thumbnail
    local_thumbnail_path, local_odc_metadata_path, local_stac_metadata_path = add_fmc_metadata_files(
        df,
        dataset,
        local_tif,
        product_name,
        product_version,
        region_code,
        acquisition_date,
        local_thumbnail_path,
        s3_folder,
    )

    os.remove(local_thumbnail_path)
    os.remove(local_odc_metadata_path)
    os.remove(local_stac_metadata_path)
    os.remove(local_tif)

    sys.exit(0)


# -------------------- Click CLI Commands -------------------- #


@click.group()
@click.version_option(version=dea_fmc.__version__)
def main() -> None:
    """Run dea-fmc."""


@main.command(no_args_is_help=True)
@click.option(
    "--dataset-uuid", "-d", type=str, required=True, help="Dataset UUID to process."
)
@click.option(
    "--process-cfg-url",
    "-p",
    type=str,
    required=True,
    help="URL to FMC process configuration file in YAML format.",
)
@click.option(
    "--overwrite/--no-overwrite",
    default=True,
    help="Rerun scenes that have already been processed.",
)
def fmc_processing(dataset_uuid: str, process_cfg_url: str, overwrite: bool) -> None:
    """Process FMC for a given dataset UUID and configuration."""
    process_dataset(dataset_uuid, process_cfg_url, overwrite)


@main.command()
@click.option(
    "--dataset-uuid",
    "-d",
    type=str,
    required=True,
    help="Dataset UUID to submit to AWS SQS.",
)
@click.option(
    "--queue-url",
    "-q",
    type=str,
    required=True,
    help="AWS SQS Queue URL to submit the message to.",
)
def submit_message(dataset_uuid: str, queue_url: str) -> None:
    """Submit a dataset UUID as a message to AWS SQS."""
    sqs = boto3.client("sqs")
    response = sqs.send_message(QueueUrl=queue_url, MessageBody=dataset_uuid)
    click.echo(f"Message submitted to SQS with MessageId: {response.get('MessageId')}")


@main.command()
@click.option(
    "--queue-url",
    "-q",
    type=str,
    required=True,
    help="AWS SQS Queue URL to read messages from.",
)
@click.option(
    "--process-cfg-url",
    "-p",
    type=str,
    required=True,
    help="URL to FMC process configuration file in YAML format.",
)
@click.option(
    "--overwrite/--no-overwrite",
    default=True,
    help="Rerun scenes that have already been processed.",
)
def fmc_processing_with_sqs(
    queue_url: str, process_cfg_url: str, overwrite: bool
) -> None:
    """
    Continuously load messages from AWS SQS and process each dataset using FMC classification.
    Exits after 10 consecutive empty polls.
    """
    sqs = boto3.client("sqs")
    no_message_count = 0

    while True:
        response = sqs.receive_message(
            QueueUrl=queue_url, MaxNumberOfMessages=10, WaitTimeSeconds=10
        )
        messages = response.get("Messages", [])
        if not messages:
            no_message_count += 1
            click.echo(
                f"No messages found in the queue. Attempt {no_message_count} of 10."
            )
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
                sqs.delete_message(
                    QueueUrl=queue_url, ReceiptHandle=message["ReceiptHandle"]
                )
                click.echo(
                    f"Processed and deleted message for dataset UUID: {dataset_uuid}"
                )
            except Exception as e:
                click.echo(f"Error processing dataset UUID {dataset_uuid}: {e}")

    click.echo("Finished processing messages from SQS.")


if __name__ == "__main__":
    main()
