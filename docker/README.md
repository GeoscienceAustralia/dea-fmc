# Integration test setup

## Integration test data
### Setting up a new database dump

```
    # Bring up indexing and database container
    docker-compose -f docker/docker-compose.index.yaml -f docker/docker-compose.cleandb.yaml up

    # Start by going to index container
    docker exec -ti docker-index-1 bash
    datacube system init
    exit
```

### Indexing and creating database dump

The products indexed into the existing database dump are:

- https://explorer.sandbox.dea.ga.gov.au/products/ga_s2am_ard_3/datasets/52dda32c-cb4b-49eb-a31d-bcf70bf62751

```
  # Start by going to index container
  docker exec -ti docker-index-1 bash

  # Indexing example:
  # - Add a new product
  datacube metadata add https://raw.githubusercontent.com/GeoscienceAustralia/dea-config/master/product_metadata/eo3_sentinel_ard.odc-type.yaml
  datacube product add https://raw.githubusercontent.com/GeoscienceAustralia/dea-config/master/products/baseline_satellite_data/c3/ga_s2am_ard_3.odc-product.yaml

  # - Index datasets
  https://data.dea.ga.gov.au/baseline/ga_s2am_ard_3/55/HGA/2019/11/21/20191121T011741/ga_s2am_ard_3-2-1_55HGA_2019-11-21_final.stac-item.json 
  
  pg_dump -U odcuser -p 5432 -h postgres odc > dump.sql
  # Enter password on prompt: odcpass or to check echo $DB_PASSWORD

  # Copy the new database dump
  docker cp docker-index-1:/dump.sql dump.sql
```

### Running tests locally
