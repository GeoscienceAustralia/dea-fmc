```
$ docker-compose up -d
$ docker exec -ti fmc-fmc-1 bash
$ pip install -e .
$ fmc --message-path ./tests/ga_s2am_ard_3-2-1_55HGA_2019-11-21_final.stac-item.json --queue-url http://localstack:4566/000000000000/my-queue --model-path ./fmc/rf_fmc.pickle
$ aws s3 ls my-bucket/derivative/ga_s2_fmc_provisional_3/0-1/55/HGA/2019/11/21/20191121T011741/
2023-10-31 05:06:37       2715 ga_s2_fmc_provisional_3_55HGA_2019-11-21_interim.odc-metadata.yaml
2023-10-31 05:06:37        190 ga_s2_fmc_provisional_3_55HGA_2019-11-21_interim.proc-info.yaml
2023-10-31 05:06:37        528 ga_s2_fmc_provisional_3_55HGA_2019-11-21_interim.sha1
2023-10-31 05:06:37       4744 ga_s2_fmc_provisional_3_55HGA_2019-11-21_interim.stac-item.json
2023-10-31 05:06:49  840374244 ga_s2_fmc_provisional_3_55HGA_2019-11-21_interim_Predictions.tif
2023-10-31 05:06:37       7560 ga_s2_fmc_provisional_3_55HGA_2019-11-21_interim_thumbnail.jpg
```

visualising dask
```
$ docker exec -ti fmc-fmc-1 bash
$ apt-get install graphviz
$ pip install graphviz
```
