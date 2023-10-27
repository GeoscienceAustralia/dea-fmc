```
$ docker-compose up -d
$ docker exec -ti fmc-fmc-1 bash
$ fmc --message-path ./tests/ga_s2am_ard_3-2-1_55HGA_2019-11-21_final.stac-item.json --queue-url http://localstack:4566/000000000000/my-queue --model-path ./fmc/rf_fmc.pickle
```
