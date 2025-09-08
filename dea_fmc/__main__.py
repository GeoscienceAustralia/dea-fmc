"""
Main processing script for Fuel Moisture Content (FMC) generation.

This script includes functions for:
- Classifying FMC from Sentinel-2 Analysis Ready Data (ARD).
- Generating metadata in ODC and STAC formats.
- Handling data processing workflows from different sources (single UUID,
  list from a file, or an AWS SQS queue).
"""

import io
import json
import logging
import os
import sys
import tempfile
import warnings
from datetime import datetime as dt
from pathlib import Path
from typing import Any, Dict, Iterator, List, Tuple

import boto3
import click
import datacube
import eodatasets3.stac as eo3stac
import joblib
import matplotlib.pyplot as plt
import numpy as np
import s3fs
import xarray as xr
from botocore.exceptions import ClientError
from datacube.utils.cog import write_cog
from dea_tools.classification import sklearn_flatten, sklearn_unflatten
from eodatasets3.assemble import DatasetAssembler, serialise
from eodatasets3.images import GridSpec
from matplotlib.colors import LinearSegmentedColormap
from odc.algo import mask_cleanup
from rasterio.crs import CRS

import dea_fmc.__version__
from dea_fmc import fmc_io, helper

# --- Constants ---
NODATA_VALUE = -999
BANDS_ORDER = [
    "ndvi", "ndii", "nbart_blue", "nbart_green", "nbart_red",
    "nbart_red_edge_1", "nbart_red_edge_2", "nbart_red_edge_3",
    "nbart_nir_1", "nbart_nir_2", "nbart_swir_2", "nbart_swir_3",
]


# --- Logging Setup ---
# Configure logging
logging.getLogger("botocore.credentials").setLevel(logging.WARNING)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger(__name__)


# --- Core Classification and Data Handling ---

def classify_fmc(data: xr.Dataset, model: Any) -> xr.Dataset:
    """
    Perform FMC classification using a pre-trained model.
    """
    # Calculate spectral indices
    data["ndii"] = (data.nbart_nir_1 - data.nbart_swir_2) / (
        data.nbart_nir_1 + data.nbart_swir_2
    )
    data["ndvi"] = (data.nbart_nir_1 - data.nbart_red) / (
        data.nbart_nir_1 + data.nbart_red
    )

    data_neworder = data[BANDS_ORDER]

    # Flatten data for sklearn, replacing potential infinities
    data_flat = sklearn_flatten(data_neworder)
    data_flat = np.where(np.isinf(data_flat), NODATA_VALUE, data_flat)

    # Predict and reshape back to original xarray dimensions
    out_class = model.predict(data_flat)
    returned_result = sklearn_unflatten(out_class, data).transpose()

    return xr.Dataset(
        {"fmc": returned_result}, coords=data.coords, attrs=data.attrs
    )


def generate_thumbnail(masked_data: xr.Dataset, output_path: str) -> None:
    """
    Generate a thumbnail image from masked data using a custom colormap.
    """
    colours = [(0.87, 0, 0), (1, 1, 0.73), (0.165, 0.615, 0.957)]  # Red, Yellow, Blue
    cmap = LinearSegmentedColormap.from_list("fmc", colours, N=256)
    data_to_plot = masked_data.fmc.squeeze()
    height, width = data_to_plot.shape
    dpi = 100

    fig, ax = plt.subplots(figsize=(width / dpi, height / dpi), dpi=dpi)
    ax.imshow(data_to_plot, cmap=cmap, interpolation="none")
    ax.axis("off")
    fig.subplots_adjust(left=0, right=1, top=1, bottom=0)

    fig.savefig(
        output_path, dpi=dpi, bbox_inches="tight", pad_inches=0, format="jpg"
    )
    plt.close(fig)


# --- Metadata Generation ---

def add_fmc_metadata_files(
    ard_dataset: xr.Dataset,
    dc_dataset: datacube.model.Dataset,
    local_tif_path: str,
    product_name: str,
    product_version: str,
    acquisition_date: str,
    acquisition_time: str,
    local_thumbnail_path: str,
    s3_folder: str,
) -> Tuple[str, str, str]:
    """
    Generate and upload ODC and STAC metadata for the FMC product.
    """
    region_code = dc_dataset.metadata.region_code
    title = f"{product_name}_{region_code}_{acquisition_date}"

    # Initialize the DatasetAssembler
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", UserWarning)
        assembler = DatasetAssembler(
            naming_conventions="dea_c3",
            dataset_location=Path(f"https://explorer.dea.ga.gov.au/product/{product_name}"),
            allow_absolute_paths=True,
        )
        source_dataset_doc = serialise.from_doc(
            dc_dataset.metadata_doc, skip_validation=True
        )
        assembler.add_source_dataset(
            source_dataset_doc,
            classifier="ard",
            auto_inherit_properties=True,
            inherit_geometry=True,
        )

    # Set key metadata properties
    assembler.platform = source_dataset_doc.properties.get("eo:platform")
    assembler.instrument = source_dataset_doc.properties.get("eo:instrument")
    assembler.geometry = ard_dataset.geobox.extent.geom

    assembler.datetime = acquisition_time

    assembler.product_name = product_name
    assembler.dataset_version = product_version
    assembler.region_code = region_code
    assembler.properties["title"] = title
    assembler.properties["odc:file_format"] = "GeoTIFF"
    assembler.properties["odc:producer"] = "ga.gov.au"
    assembler.properties["odc:product_family"] = "fmc"
    assembler.maturity = "final"
    assembler.collection_number = 3
    assembler.properties["eo:gsd"] = 20
    assembler.processed = dt.utcnow()

    # Add measurement and accessory info
    assembler.note_measurement(
        "fmc",
        local_tif_path,
        expand_valid_data=False,
        grid=GridSpec(
            shape=ard_dataset.geobox.shape,
            transform=ard_dataset.geobox.transform,
            crs=CRS.from_epsg(ard_dataset.geobox.crs.to_epsg()),
        ),
        nodata=NODATA_VALUE,
    )
    thumbnail_filename = f"{title}_thumbnail.jpg"
    assembler._accessories["thumbnail"] = thumbnail_filename

    # --- ODC and STAC File Generation ---
    odc_doc = assembler.to_dataset_doc()

    local_stac_path = f"{title}.stac-item.json"
    local_odc_path = f"{title}.odc-metadata.yaml"
    s3_stac_path = f"{s3_folder}/{local_stac_path}"
    s3_odc_path = f"{s3_folder}/{local_odc_path}"
    s3_tif_path = f"{s3_folder}/{Path(local_tif_path).name}"
    s3_thumbnail_path = f"{s3_folder}/{thumbnail_filename}"

    # Create STAC item and correct asset paths
    stac_item = eo3stac.to_stac_item(
        dataset=odc_doc,
        stac_item_destination_url=s3_stac_path,
        dataset_location=s3_folder,
        odc_dataset_metadata_url=s3_odc_path,
        explorer_base_url=f"https://explorer.dea.ga.gov.au/product/{product_name}",
    )
    stac_item["assets"]["fmc"]["href"] = s3_tif_path
    stac_item["assets"]["thumbnail"]["href"] = s3_thumbnail_path

    # Write and upload STAC metadata
    with open(local_stac_path, "w") as f:
        json.dump(stac_item, f, indent=4)
    logger.info("Uploading STAC metadata to %s", s3_stac_path)
    fmc_io.upload_object_to_s3(local_stac_path, s3_stac_path)

    # Write and upload ODC metadata
    with io.StringIO() as meta_stream, open(local_odc_path, "w") as f:
        serialise.to_stream(meta_stream, odc_doc)
        f.write(meta_stream.getvalue())
    logger.info("Uploading ODC metadata to %s", s3_odc_path)
    fmc_io.upload_object_to_s3(local_odc_path, s3_odc_path)

    # Upload thumbnail
    logger.info("Uploading Thumbnail to %s", s3_thumbnail_path)
    fmc_io.upload_object_to_s3(local_thumbnail_path, s3_thumbnail_path)

    return local_thumbnail_path, local_odc_path, local_stac_path


# --- Main Processing Workflow ---

def process_dataset(dataset_uuid: str, process_cfg: Dict[str, Any], dc: datacube.Datacube, model: Any, overwrite: bool) -> None:
    """
    Orchestrates the FMC processing for a single dataset UUID.
    """
    # 1. Load dataset and apply filters
    dataset = dc.index.datasets.get(dataset_uuid)
    if not dataset:
        logger.error("Could not find dataset with UUID: %s", dataset_uuid)
        return

    if abs(dataset.metadata_doc["properties"]["gqa:abs_iterative_mean_xy"]) > 1:
        logger.info("Dataset %s failed GQA filter.", dataset_uuid)
        return
    if dataset.metadata_doc["properties"]["dea:dataset_maturity"].lower() != "final":
        logger.info("Dataset %s failed maturity filter (not 'final').", dataset_uuid)
        return
    logger.info("Dataset %s passed all filters.", dataset_uuid)

    # 2. Define output paths
    product_name = process_cfg["product"]["name"]
    product_version = str(process_cfg["product"]["version"]).replace(".", "-")
    region_code = dataset.metadata.region_code
    acquisition_date = dataset.metadata.time.begin.strftime("%Y-%m-%d")
    acquisition_time = dataset.metadata.time.begin.isoformat(timespec="microseconds").replace("+00:00", "Z")

    capture_time_str = dataset.metadata_doc["properties"]["sentinel:datatake_start_datetime"]
    dt_obj = dt.strptime(capture_time_str, "%Y-%m-%dT%H:%M:%SZ")
    formatted_capture_time = dt_obj.strftime("%Y%m%dT%H%M%S")

    s3_folder = (
        f"{process_cfg['output_folder']}/{product_name}/{product_version}/"
        f"{region_code[:2]}/{region_code[2:]}/"
        f"{acquisition_date.replace('-', '/')}/{formatted_capture_time}"
    )
    base_filename = f"{product_name}_{region_code}_{acquisition_date}_final_fmc"
    s3_tif_uri = f"{s3_folder}/{base_filename}.tif"

    if not overwrite and helper.check_s3_file_exists(s3_tif_uri):
        logger.info("Output exists and overwrite is False. Skipping %s.", s3_tif_uri)
        return

    # 3. Process data in a temporary directory for robust cleanup
    with tempfile.TemporaryDirectory() as tmpdir:
        local_tif = os.path.join(tmpdir, f"{base_filename}.tif")
        local_thumbnail = os.path.join(tmpdir, "thumbnail.jpg")

        # 4. Load data
        ard_dataset = dc.load(
            datasets=[dataset],
            measurements=process_cfg["input_products"]["input_bands"],
            resolution=(-20, 20),
            resampling={"*": "bilinear"},
            output_crs=dataset.crs.crs_str,
        )

        # 5. Create masks
        cloud_mask = (ard_dataset.oa_fmask == 2) | (ard_dataset.oa_fmask == 3)
        water_mask = (
            (ard_dataset.oa_fmask == 5) | (ard_dataset.oa_fmask == 0) |
            (ard_dataset.oa_nbart_contiguity == 0)
        )
        cleaned_cloud_mask = mask_cleanup(
            mask=cloud_mask, mask_filters=[("opening", 1), ("dilation", 3)]
        )
        ard_dataset = ard_dataset.drop_vars(["oa_fmask", "oa_nbart_contiguity"])

        # 6. Classify and mask
        fmc_data = classify_fmc(ard_dataset, model)
        masked_data = fmc_data.where(~cleaned_cloud_mask & ~water_mask)

        # 7. Generate outputs
        generate_thumbnail(masked_data, local_thumbnail)
        final_fmc = masked_data.where(masked_data >= 0, NODATA_VALUE).astype("int16")
        write_cog(final_fmc.fmc, fname=local_tif, overwrite=True, nodata=NODATA_VALUE)
        logger.info("Result saved locally to: %s", local_tif)

        # 8. Upload results to S3
        helper.get_and_set_aws_credentials()
        fmc_io.upload_object_to_s3(local_tif, s3_tif_uri)
        logger.info("Uploaded result to: %s", s3_tif_uri)

        # 9. Generate and upload metadata
        add_fmc_metadata_files(
            ard_dataset, dataset, local_tif, product_name, product_version,
            acquisition_date, acquisition_time, local_thumbnail, s3_folder,
        )


# --- CLI Command Handlers ---

def get_uuid_iterator_from_file(s3_uri: str) -> Iterator[str]:
    """Yields UUIDs from a text file on S3."""
    fs = s3fs.S3FileSystem(anon=False)
    with fs.open(s3_uri, "r") as f:
        for line in f:
            yield line.strip()


def get_uuid_iterator_from_sqs(queue_url: str, max_empty_polls: int = 10) -> Iterator[Tuple[str, str]]:
    """Yields (UUID, ReceiptHandle) tuples from an SQS queue."""
    sqs = boto3.client("sqs")
    empty_poll_count = 0
    while empty_poll_count < max_empty_polls:
        response = sqs.receive_message(
            QueueUrl=queue_url, MaxNumberOfMessages=10, WaitTimeSeconds=20
        )
        messages = response.get("Messages", [])
        if not messages:
            empty_poll_count += 1
            logger.info("No messages in queue. Empty poll count: %d/%d.", empty_poll_count, max_empty_polls)
            continue
        
        empty_poll_count = 0  # Reset on message receipt
        for msg in messages:
            yield msg["Body"], msg["ReceiptHandle"]

    logger.warning("Exiting after %d consecutive empty polls.", max_empty_polls)


@click.group()
@click.version_option(version=dea_fmc.__version__)
def main() -> None:
    """Run Digital Earth Australia Fuel Moisture Content workflows."""
    pass


@main.command()
@click.option("--dataset-uuid", "-d", required=True, help="A single dataset UUID to process.")
@click.option("-p", "--process-cfg-url", required=True, help="URL to the YAML process configuration file.")
@click.option("--overwrite/--no-overwrite", default=False, help="Rerun and overwrite existing outputs.")
def run_single(dataset_uuid: str, process_cfg_url: str, overwrite: bool) -> None:
    """Process a single dataset UUID."""
    process_cfg = helper.load_yaml_remote(process_cfg_url)
    dc = datacube.Datacube(app="fmc_single_processor")
    
    # Define a temporary local path for the model file
    local_model_path = "temp_model.joblib"

    try:
        # Download the model from the URL in the config to the local path
        helper.download_file_from_s3_public(process_cfg["model_path"], local_model_path)
        model = joblib.load(local_model_path)
        
        # Process the dataset using the loaded model
        process_dataset(dataset_uuid, process_cfg, dc, model, overwrite)
        
    except Exception:
        logger.exception("Processing failed for UUID %s", dataset_uuid)
    finally:
        # Ensure the downloaded model file is cleaned up
        if os.path.exists(local_model_path):
            os.remove(local_model_path)
            logger.info("Cleaned up temporary model file.")


@main.command()
@click.option("-f", "--dataset-txt-file", required=True, help="S3 URI to a text file containing dataset UUIDs.")
@click.option("-p", "--process-cfg-url", required=True, help="URL to the YAML process configuration file.")
@click.option("--overwrite/--no-overwrite", default=False, help="Rerun and overwrite existing outputs.")
def run_from_file(dataset_txt_file: str, process_cfg_url: str, overwrite: bool) -> None:
    """Process a list of dataset UUIDs from a text file on S3."""
    process_cfg = helper.load_yaml_remote(process_cfg_url)
    dc = datacube.Datacube(app="fmc_file_processor")
    
    local_model_path = "temp_model.joblib"
    
    try:
        helper.download_file_from_s3_public(process_cfg["model_path"], local_model_path)
        model = joblib.load(local_model_path)
    
        uuid_iterator = get_uuid_iterator_from_file(dataset_txt_file)
        for uuid in uuid_iterator:
            try:
                logger.info("Processing dataset UUID: %s", uuid)
                process_dataset(uuid, process_cfg, dc, model, overwrite)
            except Exception:
                logger.exception("Processing failed for UUID %s. Continuing to next.", uuid)
                continue
    finally:
        if os.path.exists(local_model_path):
            os.remove(local_model_path)
            logger.info("Cleaned up temporary model file.")


@main.command()
@click.option("-q", "--queue-url", required=True, help="AWS SQS Queue URL to read messages from.")
@click.option("-p", "--process-cfg-url", required=True, help="URL to the YAML process configuration file.")
@click.option("--overwrite/--no-overwrite", default=False, help="Rerun and overwrite existing outputs.")
def run_from_sqs(queue_url: str, process_cfg_url: str, overwrite: bool) -> None:
    """Continuously process dataset UUIDs from an AWS SQS queue."""
    process_cfg = helper.load_yaml_remote(process_cfg_url)
    dc = datacube.Datacube(app="fmc_sqs_processor")
    sqs_client = boto3.client("sqs")

    local_model_path = "temp_model.joblib"

    try:
        helper.download_file_from_s3_public(process_cfg["model_path"], local_model_path)
        model = joblib.load(local_model_path)

        for uuid, receipt_handle in get_uuid_iterator_from_sqs(queue_url):
            try:
                logger.info("Processing dataset UUID: %s", uuid)
                process_dataset(uuid, process_cfg, dc, model, overwrite)
                sqs_client.delete_message(QueueUrl=queue_url, ReceiptHandle=receipt_handle)
                logger.info("Successfully processed and deleted message for %s", uuid)
            except Exception:
                logger.exception("Processing failed for UUID %s. Message will not be deleted.", uuid)
                continue
    finally:
        if os.path.exists(local_model_path):
            os.remove(local_model_path)
            logger.info("Cleaned up temporary model file.")


if __name__ == "__main__":
    main()