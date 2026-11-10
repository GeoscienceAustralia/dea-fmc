
import numpy as np
import pytest
import xarray as xr
from PIL import Image

from dea_fmc.__main__ import generate_thumbnail


@pytest.mark.parametrize(
    "shape",
    [
        (5, 2),       # Small July-style footprint
        (1, 5),       # Singleton spatial dimension
        (5, 1),
        (10, 10),     # Minimum standard downsampling
        (100, 100),   # Normal scene
        (103, 107),   # Non-divisible dimensions
    ],
)
def test_thumbnail_generation(tmp_path, shape):
    data = xr.Dataset(
        {
            "fmc": (
                ("time", "y", "x"),
                np.full((1, *shape), 50.0, dtype=np.float32),
            )
        }
    )

    output = tmp_path / "thumbnail.jpg"

    generate_thumbnail(data, str(output))

    assert output.exists()
    assert output.stat().st_size > 0

    with Image.open(output) as image:
        image.verify()


def test_empty_raster_rejected(tmp_path):
    data = xr.Dataset(
        {
            "fmc": (
                ("y", "x"),
                np.empty((0, 0), dtype=np.float32),
            )
        }
    )

    with pytest.raises(ValueError, match="empty raster"):
        generate_thumbnail(
            data,
            str(tmp_path / "empty.jpg"),
        )
