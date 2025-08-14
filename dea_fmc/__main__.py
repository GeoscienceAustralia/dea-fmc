import io
import json
import logging
import os
import sys
import tempfile
import warnings
from datetime import datetime as dt
from pathlib import Path
from typing import Dict, Iterator, List, Tuple

import boto3
import click
import datacube
import eodatasets3.stac as eo3stac
import joblib
import matplotlib.pyplot as plt
import numpy as np
import s3fs
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

# --- Constants ---
# Using constants makes the code more readable and easier to maintain.
NODATA_VALUE = -999
FMC_MODEL_BANDS = [
    "ndvi", "ndii", "nbart_blue", "nbart_green", "nbart_red",
    "nbart_red_edge_1", "nbart_red_edge_2", "nbart_red_edge_3",
    "nbart_nir_1", "nbart_nir_2", "nbart_swir_2", "nbart_swir_3",
]
# Mapping of input ARD product names to output FMC product names.
PRODUCT_MAP = {
    "ga_s2am_ard_3": "ga_s2am_fmc_3",
    "ga_s2bm_ard_3": "ga_s2bm_fmc_3",
    "ga_s2cm_ard_3": "ga_s2cm_fmc_3",
}

# --- Logging Setup ---
# Configure logging at the application's entry point for simplicity.
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    stream=sys.stdout,
)
# Quieten overly verbose libraries
logging.getLogger("botocore.credentials").setLevel(logging.WARNING)
logging.getLogger("sqlalchemy").setLevel(logging.WARNING)
LOGGER = logging.getLogger(__name__)


def classify_fmc(data: xr.Dataset, model) -> xr.Dataset:
    """
    Perform FMC classification using a pre-trained model.

    This function calculates required spectral indices, reorders bands to match
    model expectations, flattens the data for prediction, and returns a
    Dataset containing the 'fmc' classification.

    :param data: Input `xarray.Dataset` with required spectral bands.
    :param model: A pre-trained scikit-learn compatible model.
    :return: An `xarray.Dataset` with the 'fmc' data variable.
    """
    # Calculate spectral indices required by the model
    data["ndii"] = (data.nbart_nir_1 - data.nbart_swir_2) / (
        data.nbart_nir_1 + data.nbart_swir_2
    )
    data["ndvi"] = (data.nbart_nir_1 - data.nbart_red) / (
        data.nbart_nir_1 + data.nbart_red
    )

    # Ensure band order matches the model's training data
    data_neworder = data[FMC_MODEL_BANDS]

    # Flatten data, replacing potential infinities from division-by-zero with nodata
    data_flat = sklearn_flatten(data_neworder)
    data_flat = np.where(np.isinf(data_flat), NODATA_VALUE, data_flat)

    # Run prediction and reshape back to the original raster dimensions
    out_class = model.predict(data_flat)
    returned_result = sklearn_unflatten(out_class, data)  # No need for transpose

    return xr.Dataset({"fmc": returned_result}, coords=data.coords, attrs=data.attrs)


def generate_and_upload_metadata(
    ard_dataset: xr.Dataset,
    dc_dataset: datacube.model.Dataset,
    cfg: dict,
    s3_paths: dict,
    local_paths: dict,
) -> None:
    """
    Generate ODC and STAC metadata, and upload all artifacts to S3.

    :param ard_dataset: The `xarray.Dataset` of the source data.
    :param dc_dataset: The `datacube.model.Dataset` of the source data.
    :param cfg: The processing configuration dictionary.
    :param s3_paths: A dictionary of S3 URIs for the output files.
    :param local_paths: A dictionary of local paths for the output files.
    """
    product_cfg = cfg["product"]
    region_code = dc_dataset.metadata.fields["region_code"]
    acquisition_date = dc_dataset.metadata.fields["time"][0].date()
    title = f"{s3_paths['product_name']}_{region_code}_{acquisition_date:%Y-%m-%d}"

    LOGGER.info("Starting metadata generation.")
    
    # Use a context manager to suppress warnings locally
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", UserWarning)
        
        assembler = DatasetAssembler(
            naming_conventions="dea_c3",
            dataset_location=Path(f"https://explorer.dea.ga.gov.au/product/{product_cfg['name']}"),
            allow_absolute_paths=True,
        )

        source_doc = serialise.from_doc(dc_dataset.metadata_doc, skip_validation=True)
        assembler.add_source_dataset(
            source_doc,
            classifier="ard",
            auto_inherit_properties=True,
            inherit_geometry=True,
        )

    # Set core metadata properties
    assembler.platform = source_doc.properties.get("eo:platform")
    assembler.instrument = source_doc.properties.get("eo:instrument")
    assembler.geometry = ard_dataset.geobox.extent.geom
    assembler.datetime = acquisition_date
    assembler.processed = dt.utcnow()

    # Set product-specific properties from config
    assembler.product_name = s3_paths['product_name']
    assembler.dataset_version = str(product_cfg["version"]).replace(".", "-")
    assembler.region_code = region_code
    assembler.properties.update({
        "title": title,
        "odc:file_format": "GeoTIFF",
        "odc:producer": "ga.gov.au",
        "odc:product_family": "fmc",
        "dea:maturity": "final", # Assuming output is always final
    })

    assembler.note_measurement(
        "fmc",
        local_paths['cog'],
        expand_valid_data=False,
        grid=GridSpec.from_geobox(ard_dataset.geobox),
        nodata=NODATA_VALUE,
    )
    
    assembler.extend_user_metadata("input-products", cfg["input_products"]["names"])

    # --- ODC Metadata ---
    odc_meta = assembler.to_dataset_doc()
    meta_stream = io.StringIO()
    serialise.to_stream(meta_stream, odc_meta)
    with open(local_paths['odc_yaml'], "w") as f:
        f.write(meta_stream.getvalue())
    LOGGER.info("Uploading ODC metadata to %s", s3_paths['odc_yaml'])
    fmc_io.upload_object_to_s3(local_paths['odc_yaml'], s3_paths['odc_yaml'])

    # --- STAC Metadata ---
    stac_meta = eo3stac.to_stac_item(
        dataset=odc_meta,
        stac_item_destination_url=s3_paths['stac_json'],
        odc_dataset_metadata_url=s3_paths['odc_yaml'],
        dataset_location=s3_paths['folder'],
        explorer_base_url=f"https://explorer.dea.ga.gov.au/product/{product_cfg['name']}",
    )
    # Manually correct asset paths to be absolute S3 URIs
    stac_meta["assets"]["fmc"]["href"] = s3_paths['cog']
    stac_meta["assets"]["thumbnail"] = {"href": s3_paths['thumbnail'], "type": "image/jpeg"}

    with open(local_paths['stac_json'], "w") as f:
        json.dump(stac_meta, f, indent=4)
    LOGGER.info("Uploading STAC metadata to %s", s3_paths['stac_json'])
    fmc_io.upload_object_to_s3(local_paths['stac_json'], s3_paths['stac_json'])


def generate_thumbnail(masked_fmc: xr.DataArray, output_path: str) -> None:
    """
    Generate a thumbnail image from masked data using a custom colormap.

    :param masked_fmc: `xarray.DataArray` of the FMC data to plot.
    :param output_path: The local file path to save the generated thumbnail.
    """
    LOGGER.info("Generating thumbnail...")
    colours = [(0.87, 0, 0), (1, 1, 0.73), (0.165, 0.615, 0.957)]
    cmap = LinearSegmentedColormap.from_list("fmc", colours, N=256)

    data_to_plot = masked_fmc.squeeze()
    height, width = data_to_plot.shape
    dpi = 100

    fig, ax = plt.subplots(figsize=(width / dpi, height / dpi), dpi=dpi)
    ax.imshow(data_to_plot, cmap=cmap, interpolation="none")
    ax.axis("off")
    fig.subplots_adjust(left=0, right=1, top=1, bottom=0, wspace=0, hspace=0)

    plt.savefig(output_path, dpi=dpi, format="jpg")
    plt.close(fig)
    LOGGER.info("Thumbnail saved to %s", output_path)

def _generate_s3_paths(dataset: datacube.model.Dataset, cfg: dict) -> Dict[str, str]:
    """Helper function to generate all required S3 output paths."""
    output_folder = cfg["output_folder"]
    product_cfg = cfg["product"]
    product_version = str(product_cfg["version"]).replace(".", "-")
    
    region_code = dataset.metadata.fields["region_code"]
    acq_date = dataset.metadata.fields["time"][0].date()
    acq_date_str = acq_date.strftime("%Y-%m-%d")
    
    fmc_product_name = PRODUCT_MAP[dataset.product.name]
    
    base_filename = f"{fmc_product_name}_{region_code}_{acq_date_str}"

    s3_folder = (
        f"{output_folder}/{product_cfg['name']}/{product_version}/{region_code[:2]}/{region_code[2:]}/"
        f"{acq_date.year}/{acq_date.month:02d}/{acq_date.day:02d}"
    )

    return {
        "folder": s3_folder,
        "product_name": fmc_product_name,
        "cog": f"{s3_folder}/{base_filename}_final_fmc.tif",
        "thumbnail": f"{s3_folder}/{base_filename}_thumbnail.jpg",
        "stac_json": f"{s3_folder}/{base_filename}.stac-item.json",
        "odc_yaml": f"{s3_folder}/{base_filename}.odc-metadata.yaml",
    }


def process_dataset(dataset_uuid: str, process_cfg_url: str, overwrite: bool) -> None:
    """
    Main processing pipeline for a single dataset UUID.

    :param dataset_uuid: The UUID of the dataset to process.
    :param process_cfg_url: URL to the YAML processing configuration file.
    :param overwrite: If True, re-process even if output exists.
    """
    # --- 1. Initial Setup and Pre-flight Checks ---
    dc = datacube.Datacube(app=f"fmc_processing_{dea_fmc.__version__}")
    os.environ["AWS_NO_SIGN_REQUEST"] = "Yes"

    cfg = helper.load_yaml_remote(process_cfg_url)
    dataset = dc.index.datasets.get(dataset_uuid)

    if not dataset:
        LOGGER.warning("Dataset %s not found in the Datacube index.", dataset_uuid)
        return

    if dataset.product.name not in PRODUCT_MAP:
        LOGGER.warning("Product %s is not a supported input product. Skipping.", dataset.product.name)
        return
        
    if abs(dataset.metadata_doc["properties"].get("gqa:abs_iterative_mean_xy", 2)) > 1:
        LOGGER.info("Dataset %s fails GQA check. Skipping.", dataset_uuid)
        return

    if dataset.metadata_doc["properties"].get("dea:dataset_maturity", "nrt").lower() != "final":
        LOGGER.info("Dataset %s is not 'final' maturity. Skipping.", dataset_uuid)
        return
    
    s3_paths = _generate_s3_paths(dataset, cfg)
    if not overwrite and helper.check_s3_file_exists(s3_paths['cog']):
        LOGGER.info("Output exists and overwrite is False. Skipping %s.", s3_paths['cog'])
        return
    
    # --- 2. Data Loading and Classification ---
    local_model_path = "RF_model.joblib"
    local_paths = {}

    try:
        # Download and load the model
        helper.download_file_from_s3_public(cfg["model_path"], local_model_path)
        model = joblib.load(local_model_path)

        # Load ARD data
        ds_crs = dataset.metadata_doc['crs']
        input_data = dc.load(
            datasets=[dataset],
            measurements=cfg["input_products"]["input_bands"],
            resolution=(-20, 20),
            resampling={"*": "bilinear"},
            output_crs=ds_crs,
        )

        # Create masks from fmask and contiguity
        cloud_mask = (input_data.oa_fmask == 2) | (input_data.oa_fmask == 3)
        water_mask = (input_data.oa_fmask == 5) | (input_data.oa_fmask == 0) | (input_data.oa_nbart_contiguity == 0)
        better_cloud_mask = mask_cleanup(mask=cloud_mask, mask_filters=[("opening", 1), ("dilation", 3)])
        
        # Drop mask bands to free up memory
        input_data = input_data.drop_vars(["oa_fmask", "oa_nbart_contiguity"])

        fmc_data = classify_fmc(input_data, model)
        masked_fmc = fmc_data.where(~better_cloud_mask & ~water_mask)
        
        # --- 3. Generate and Upload Outputs ---
        # Create temporary files for outputs to ensure cleanup
        with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as thumb_f, \
             tempfile.NamedTemporaryFile(suffix=".tif", delete=False) as cog_f, \
             tempfile.NamedTemporaryFile(suffix=".stac-item.json", delete=False) as stac_f, \
             tempfile.NamedTemporaryFile(suffix=".odc-metadata.yaml", delete=False) as odc_f:
            
            local_paths = {
                'thumbnail': thumb_f.name,
                'cog': cog_f.name,
                'stac_json': stac_f.name,
                'odc_yaml': odc_f.name,
            }

        # Generate thumbnail *before* applying final nodata value
        generate_thumbnail(masked_fmc.fmc, local_paths['thumbnail'])

        # Set final nodata value and cast to integer
        masked_fmc = masked_fmc.where(masked_fmc >= 0, NODATA_VALUE).astype("int16")
        
        # Write COG and upload
        write_cog(masked_fmc.fmc, fname=local_paths['cog'], overwrite=True, nodata=NODATA_VALUE)
        LOGGER.info("Result saved locally to: %s", local_paths['cog'])
        
        # Set AWS credentials for upload
        helper.get_and_set_aws_credentials()
        fmc_io.upload_object_to_s3(local_paths['cog'], s3_paths['cog'])
        LOGGER.info("Uploaded result to: %s", s3_paths['cog'])
        fmc_io.upload_object_to_s3(local_paths['thumbnail'], s3_paths['thumbnail'])
        LOGGER.info("Uploaded thumbnail to: %s", s3_paths['thumbnail'])
        
        # Generate and upload metadata
        generate_and_upload_metadata(input_data, dataset, cfg, s3_paths, local_paths)
        
        LOGGER.info("Successfully processed dataset %s", dataset_uuid)

    finally:
        # --- 4. Cleanup ---
        # Clean up all local temporary files
        for path in local_paths.values():
            if os.path.exists(path):
                os.remove(path)
                LOGGER.debug("Removed temporary file: %s", path)
        if os.path.exists(local_model_path):
            os.remove(local_model_path)


# ==================== CLICK CLI Section ====================

def _process_tasks(tasks: Iterator[str], process_cfg_url: str, overwrite: bool) -> None:
    """
    Iterates through tasks and processes them.

    This function provides a single point of execution for processing,
    decoupling the task source (SQS, file, single UUID) from the worker logic.

    :param tasks: An iterator yielding dataset UUIDs.
    :param process_cfg_url: URL to the YAML processing configuration file.
    :param overwrite: If True, re-process even if output exists.
    """
    for i, task in enumerate(tasks):
        LOGGER.info("Starting task %d: %s", i + 1, task)
        try:
            process_dataset(task, process_cfg_url, overwrite)
        except Exception as e:
            LOGGER.error("Failed to process task %s", task, exc_info=e)

@click.group(context_settings=dict(help_option_names=["-h", "--help"]))
@click.version_option(version=dea_fmc.__version__)
def main() -> None:
    """dea-fmc: A tool for processing Fuel Moisture Content."""
    pass

# --- Task Generators ---
def s3_file_tasks(txt_file_uri: str) -> Iterator[str]:
    """Yields UUIDs from a text file on S3."""
    LOGGER.info("Reading UUIDs from %s", txt_file_uri)
    fs = s3fs.S3FileSystem(anon=False)
    with fs.open(txt_file_uri, "r") as f:
        for line in f:
            yield line.strip()

def sqs_tasks(queue_url: str, max_retries: int = 10) -> Iterator[str]:
    """Yields UUIDs from an SQS queue."""
    sqs = boto3.client("sqs")
    empty_polls = 0
    while empty_polls < max_retries:
        response = sqs.receive_message(
            QueueUrl=queue_url, MaxNumberOfMessages=10, WaitTimeSeconds=10
        )
        messages = response.get("Messages", [])
        if not messages:
            empty_polls += 1
            LOGGER.info("No messages found. Empty poll count: %d/%d", empty_polls, max_retries)
            continue
        
        empty_polls = 0  # Reset on successful poll
        for msg in messages:
            yield msg["Body"]
            # A more robust system might move failed messages to a DLQ
            # instead of just not deleting them. For simplicity, we delete on yield.
            sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=msg["ReceiptHandle"])
            LOGGER.info("Processed and deleted message for %s", msg["Body"])
    LOGGER.warning("Exceeded max SQS retries (%d). Exiting.", max_retries)


# --- CLI Commands ---
@main.command(no_args_is_help=True)
@click.option("--dataset-uuid", "-d", required=True, help="A single dataset UUID to process.")
@click.option("--process-cfg-url", "-p", required=True, help="URL to the YAML process config.")
@click.option("--overwrite/--no-overwrite", default=False, help="Overwrite existing outputs.")
def run_single(dataset_uuid: str, process_cfg_url: str, overwrite: bool):
    """Process a single dataset UUID."""
    _process_tasks(iter([dataset_uuid]), process_cfg_url, overwrite)

@main.command(no_args_is_help=True)
@click.option("--s3-txt-file", "-f", required=True, help="S3 URI to a .txt file of UUIDs.")
@click.option("--process-cfg-url", "-p", required=True, help="URL to the YAML process config.")
@click.option("--overwrite/--no-overwrite", default=False, help="Overwrite existing outputs.")
def run_from_file(s3_txt_file: str, process_cfg_url: str, overwrite: bool):
    """Process a list of datasets from a text file on S3."""
    tasks = s3_file_tasks(s3_txt_file)
    _process_tasks(tasks, process_cfg_url, overwrite)

@main.command(no_args_is_help=True)
@click.option("--queue-url", "-q", required=True, help="The AWS SQS queue URL to poll for tasks.")
@click.option("--process-cfg-url", "-p", required=True, help="URL to the YAML process config.")
@click.option("--overwrite/--no-overwrite", default=False, help="Overwrite existing outputs.")
def run_from_sqs(queue_url: str, process_cfg_url: str, overwrite: bool):
    """Poll an SQS queue and process dataset UUIDs as messages."""
    tasks = sqs_tasks(queue_url)
    _process_tasks(tasks, process_cfg_url, overwrite)

if __name__ == "__main__":
    main()