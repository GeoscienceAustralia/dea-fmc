export pgdata=$(pwd)/.dbdata
export DATACUBE_DB_URL=postgresql:///odc

# unless already set up
if [ ! -d "${pgdata}" ]; then
    echo "Creating ${pgdata}"
    mkdir ${pgdata}

    initdb -D ${pgdata} --auth-host=md5 --encoding=UTF8
    pg_ctl -D ${pgdata} -l logfile start
    createdb odc
    psql -d odc -c "CREATE USER odc WITH PASSWORD 'odc';"
    psql -d odc -c "GRANT ALL PRIVILEGES ON DATABASE odc TO odc;"
fi

pg_ctl -D ${pgdata} -l "${pgdata}/pg.log" start
datacube system init

# datacube system check