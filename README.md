# Digital Earth Australia Fuel Moisture Content

Testing

```
$ docker-compose build fmc

$ docker-compose up -d
$ docker exec -ti fmc-fmc-1 bash
$ pip install -e .

# send a test message for consuming from local SQS queue
$ python fmc/send.py

# trigger processing
$ fmc --queue-url http://localstack:4566/000000000000/my-queue --model-path /app/rf_fmc.pickle

# when completed will be written to local S3 bucket
$ aws s3 ls s3://my-bucket/derivative/ga_s2_fmc_provisional_3/0-1/55/HGA/2019/11/21/20191121T011741/
2023-10-31 05:06:37       2715 ga_s2_fmc_provisional_3_55HGA_2019-11-21_final.odc-metadata.yaml
2023-10-31 05:06:37        190 ga_s2_fmc_provisional_3_55HGA_2019-11-21_final.proc-info.yaml
2023-10-31 05:06:37        528 ga_s2_fmc_provisional_3_55HGA_2019-11-21_final.sha1
2023-10-31 05:06:37       4744 ga_s2_fmc_provisional_3_55HGA_2019-11-21_final.stac-item.json
2023-10-31 05:06:49  840374244 ga_s2_fmc_provisional_3_55HGA_2019-11-21_final_Predictions.tif
2023-10-31 05:06:37       7560 ga_s2_fmc_provisional_3_55HGA_2019-11-21_final_thumbnail.jpg
```

Visualising dask

```
$ docker exec -ti fmc-fmc-1 bash
$ apt-get install graphviz
$ pip install graphviz

Browse to http://localhost:8787/
# might give error about needing to install bokeh - do that
```
