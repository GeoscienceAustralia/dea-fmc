from datacube.testutils.io import native_geobox
from eodatasets3.assemble import DatasetAssembler, serialise
from eodatasets3.model import DatasetDoc, ProductDoc
from eodatasets3.properties import StacPropertyView
from eodatasets3.scripts.tostac import dc_to_stac, json_fallback
from eodatasets3.verify import PackageChecksum

from datetime import datetime
import json

import subprocess

from pathlib import Path
import tempfile
from .version import version

from odc.apps.dc_tools._docs import odc_uuid

import datacube

def _write_stac(
    metadata_path: Path,
    destination_path: str,
    explorer_url: str,
    dataset_assembler: DatasetAssembler,
):
    out_dataset = serialise.from_path(metadata_path)
    stac_path = Path(str(metadata_path).replace("odc-metadata.yaml", "stac-item.json"))
    stac = dc_to_stac(
        out_dataset,
        metadata_path,
        stac_path,
        destination_path.rstrip("/") + "/",
        explorer_url,
        False,
    )
    with stac_path.open("w") as f:
        json.dump(stac, f, default=json_fallback)
    dataset_assembler.add_accessory_file("metadata:stac", stac_path)

    checksummer = PackageChecksum()
    checksum_file = (
        Path(dataset_assembler.names.dataset_location.lstrip("file:"))
        / dataset_assembler._accessories["checksum:sha1"].name
    )
    checksummer.read(checksum_file)
    checksummer.add_file(stac_path)
    checksummer.write(checksum_file)

    return stac


def save(dataset_id, output_data, s3_prefix, explorer_url):
    dc = datacube.Datacube()
    dcds = dc.index.datasets.get(dataset_id)

    uuid = odc_uuid(
        algorithm="fmc",
        algorithm_version=version,
        sources=[dataset_id],
        dataset_version="0.1"
    )
    temp_dir = tempfile.TemporaryDirectory()
    dataset_assembler = DatasetAssembler(
        collection_location=Path(temp_dir.name),
        naming_conventions="dea_s2_derivative",
        dataset_id=uuid,
    )
    dataset_assembler.product_family="fmc"
    dataset_assembler.producer="ga.gov.au"
    dataset_assembler.collection_number="3"

    properties = StacPropertyView(dcds.metadata_doc.get("properties", {}))
    if properties.get("eo:gsd"):
        del properties["eo:gsd"]
    source_doc = DatasetDoc(
        id=dataset_id,
        product=ProductDoc(name=dcds.type.name),
        crs=str(dcds.crs),
        properties=properties
    )
    dataset_assembler.add_source_dataset(
        source_doc,
        auto_inherit_properties=True,
        inherit_geometry=True,
        classifier="ard"
    )

    dataset_assembler.properties["dea:dataset_maturity"] = source_doc.properties["dea:dataset_maturity"]
    dataset_assembler.properties["dea:product_maturity"] = "provisional"
    dataset_assembler.properties["odc:product"] = "ga_s2_fmc_provisional_3"
    dataset_assembler.properties["odc:dataset_version"] = "0.1"

    dataset_assembler.properties["eo:gsd"] = native_geobox(
        dcds, basis=list(dcds.measurements.keys())[0]
    ).affine[0]

    dataset_assembler.processed = datetime.utcnow()

    dataset_assembler.note_software_version(
        "fmc",
        "https://github.com/GeoscienceAustralia/dea-fmc",
        version,
    )

    dataset_assembler.write_measurements_odc_xarray(
        output_data,
        nodata=0,  # TODO: check this
    )

    dataset_assembler.write_thumbnail(
        red="fmc",
        green="fmc",
        blue="fmc",
    )

    dataset_id, metadata_path = dataset_assembler.done()

    relative_path = dataset_assembler.names.dataset_folder
    dataset_location = Path(temp_dir.name) / relative_path

    s3_prefix = s3_prefix.rstrip("/")
    destination_path = (
        f"{s3_prefix}/{relative_path}"
    )

    stac = _write_stac(metadata_path, destination_path, explorer_url, dataset_assembler)

    s3_command = [
        "aws",
        "s3",
        "sync",
        "--only-show-errors",
        "--acl bucket-owner-full-control",
        str(dataset_location),
        destination_path,
    ]
    subprocess.run(" ".join(s3_command), shell=True, check=True)
