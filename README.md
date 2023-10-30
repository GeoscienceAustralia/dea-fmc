```
$ docker-compose up -d
$ docker exec -ti fmc-fmc-1 bash
$ pip install -e .
$ fmc --message-path ./tests/ga_s2am_ard_3-2-1_55HGA_2019-11-21_final.stac-item.json --queue-url http://localstack:4566/000000000000/my-queue --model-path ./fmc/rf_fmc.pickle
```

visualising dask
```
$ docker exec -ti fmc-fmc-1 bash
$ apt-get install graphviz
$ pip install graphviz
```
