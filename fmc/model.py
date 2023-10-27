import datacube

import numpy as np
import xarray as xr
from joblib import load
from dea_tools.classification import predict_xr
from dea_tools.dask import create_local_dask_cluster
from dea_tools.datahandling import load_ard


def process(dataset_id, model_path):
    skl_model = load(model_path)

    dc = datacube.Datacube()
    dcds = dc.index.datasets.get(dataset_id)

    measurements = ["nbart_red","nbart_green","nbart_blue",
                    "nbart_nir_1","nbart_nir_2",
                    "nbart_swir_2","nbart_swir_3"]
 
    ds = dc.load(id=dcds.id,
                 product=dcds.product.name,
                 measurements=measurements,
                 dask_chunks = {'x': 1000, 'y': 1000})

    ds['ndvi']=((ds.nbart_nir_1-ds.nbart_red)/(ds.nbart_nir_1+ds.nbart_red))
    ds['ndii']=((ds.nbart_nir_1-ds.nbart_swir_2)/(ds.nbart_nir_1+ds.nbart_swir_2))


    ds = ds[['ndvi','ndii','nbart_red','nbart_green','nbart_blue',
        'nbart_nir_1','nbart_nir_2','nbart_swir_2','nbart_swir_3']]

    ds = ds.isel(time=0)

    predicted = predict_xr(skl_model,
                        ds,
                        proba=False,
                        persist=False,
                        clean=True,
                        return_input=True).compute()

    print(predicted)