#!/bin/bash

function exit_err {
    printf "%s\n" "$1" >&2
    exit 1
}

while getopts ":d:i:" option; do
    case "$option" in
        d) PGDATA_DIR=${OPTARG};;
        i) INITIALIZATION="$OPTARG" ;;
        :) exit_err "Missing argument for -$OPTARG" ;;
        *) exit_err "Invalid option -$OPTARG" ;;
    esac
done

# Add

if [[ -f "$INITIALIZATION" ]]; then
    printf "\n======================\n"
    printf "Running Initialization\n"
    printf "======================\n\n"
    case "$INITIALIZATION" in
        *.txt)
            pip install --user -r "$INITIALIZATION" || exit_err "Failed to install packages from $INITIALIZATION"
            ;;
        *.yml|*.yaml)
            conda env update --file "$INITIALIZATION" || exit_err "Failed to update environment using $INITIALIZATION"
            ;;
        *.sh)
            bash "$INITIALIZATION" || exit_err "Failed to execute script $INITIALIZATION"
            ;;
        *)
            exit_err "File format not correct. Initialization must be specified in a *.txt, *.yml/yaml, or *.sh file."
            ;;
    esac
fi


## Start Redis
printf  "\n=============  "
printf  "\n Start Redis  \n"
printf  "============= \n\n"

REDIS_URL="redis://localhost:6379"
export REDIS_URL
echo "REDIS_URL=${REDIS_URL}" >> ~/.bashrc

redis-server --daemonize yes

printf "Done.\n\n"


## Start PostgreSQL
printf  "\n==================  "
printf  "\n Start PostgreSQL  \n"
printf  "================== \n\n"

if [ "$PGDATA_DIR" ]; then
  export PGDATA="$PGDATA_DIR"
  chmod 700 -R "$PGDATA"
  /usr/lib/postgresql/*/bin/pg_ctl -l "$PGDATA"/logfile start
  wait-for-postgres
else
  mkdir -p /work/postgresql
  export PGDATA=/work/postgresql
  /usr/lib/postgresql/*/bin/initdb -D "$PGDATA"
  /usr/lib/postgresql/*/bin/pg_ctl -l "$PGDATA"/logfile start
  wait-for-postgres
fi

## Apply configuration to PostgreSQL
NEW_ENTRY="local airflow_db airflow_user  password"

if ! grep -q "$NEW_ENTRY" "$PGDATA"/pg_hba.conf >/dev/null; then
  psql -c "CREATE DATABASE airflow_db;" \
       -c "CREATE USER airflow_user WITH PASSWORD 'airflow_pass';" \
       -c "GRANT ALL PRIVILEGES ON DATABASE airflow_db TO airflow_user;" \
       -c "USE airflow_db; GRANT ALL ON SCHEMA public TO airflow_user;" \ 
    
  echo "$NEW_ENTRY" >> "$PGDATA"/pg_hba.conf
fi
# FIXME: Check if this is necessary or it can be reordered
/usr/lib/postgresql/*/bin/pg_ctl -l "$PGDATA"/logfile restart
wait-for-postgres

## Apply configuration to Airflow
AIRFLOW__DATABASE__SQL_ALCHEMY_CONN="postgresql+psycopg2://airflow_user:airflow_pass@localhost:5432/airflow_db"
export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
echo "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=${AIRFLOW__DATABASE__SQL_ALCHEMY_CONN}" >> ~/.bashrc

AIRFLOW__CELERY__BROKER_URL="${REDIS_URL}"
export AIRFLOW__CELERY__BROKER_URL
echo "AIRFLOW__CELERY__BROKER_URL=${AIRFLOW__CELERY__BROKER_URL}" >> ~/.bashrc

# Switch from SQLite to postgres
airflow db migrate

# Create an airflow user
airflow users create \
 --username admin \
 --firstname Admin \
 --lastname Admin \
 --role Admin \
 --email admin@admin.com \
 --password admin
 
# Start Airflow
airflow webserver --port 8080 &
airflow scheduler &

sleep infinity
