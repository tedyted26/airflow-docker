#!/bin/bash

function exit_err {
    printf "%s\n" "$1" >&2
    exit 1
}

PORT=8080
USERNAME="ucloud"
PASSWORD="ucloud"

while getopts ":d:i:c:h:e:xg:f:p:u:s:" option; do
    case "$option" in
        d) PGDATA_DIR=${OPTARG};;
        i) INITIALIZATION="$OPTARG" ;;
        c) CONFIGURATION="$OPTARG" ;;
        h) AIRFLOW_HOME=${OPTARG};;
        e) AIRFLOW__CORE__EXECUTOR="$OPTARG";;
        x) AIRFLOW__CORE__LOAD__EXAMPLES="False";; 
        g) AIRFLOW__CORE__DAGS_FOLDER="$OPTARG";;
        f) AIRFLOW__CORE__FERNET_KEY="$OPTARG";;
        p) PORT="$OPTARG";;
        u) USERNAME="$OPTARG";;
        s) PASSWORD="$OPTARG";;
        # Add note too docs
        # would have to run again $ pip install "apache-airflow==2.9.1" apache-airflow-providers-google==10.1.0
        # This is to ensure pip doesnt upgrade/downgrade airflow by accident
        :) exit_err "Missing argument for -$OPTARG" ;;
        *) exit_err "Invalid option -$OPTARG" ;;
        # Add webserver_config.py?
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
NEW_ENTRY="local airflow_db airflow_user password"

if ! grep -q "$NEW_ENTRY" "$PGDATA"/pg_hba.conf >/dev/null; then
  psql postgres -c "CREATE DATABASE airflow_db;" \
        -c "CREATE USER airflow_user WITH PASSWORD 'airflow_pass';" \
        -c "GRANT ALL PRIVILEGES ON DATABASE airflow_db TO airflow_user;"
  psql airflow_db -c "GRANT ALL ON SCHEMA public TO airflow_user;"
    
  echo "$NEW_ENTRY" >> "$PGDATA"/pg_hba.conf
fi

/usr/lib/postgresql/*/bin/pg_ctl -l "$PGDATA"/logfile restart
wait-for-postgres

## Apply configuration to Airflow

printf  "\n==================  "
printf  "\n Copying configuration file  \n"
printf  "================== \n\n"
if [[ -f "$CONFIGURATION" ]]; then
    if [[ ! -d "$AIRFLOW_HOME" ]]; then
        mkdir "$AIRFLOW_HOME"
    fi
    
    cp "$CONFIGURATION" "${AIRFLOW_HOME}/airflow.cfg"
fi
# Using variables
# AIRFLOW__CORE__SQL_ALCHEMY_CONN is getting deprecated
# AIRFLOW__DATABASE__SQL_ALCHEMY_CONN will take it's place
# For now, both are needed for a correct setup, this might change in the future
declare -A airflow_variables=(
    ["AIRFLOW_HOME"]="$AIRFLOW_HOME"
    ["AIRFLOW__CORE__EXECUTOR"]="$AIRFLOW__CORE__EXECUTOR"
    ["AIRFLOW__CORE__LOAD__EXAMPLES"]="$AIRFLOW__CORE__LOAD__EXAMPLES"
    ["AIRFLOW__CORE__DAGS_FOLDER"]="$AIRFLOW__CORE__DAGS_FOLDER"
    ["AIRFLOW__CORE__FERNET_KEY"]="$AIRFLOW__CORE__FERNET_KEY"
    ["AIRFLOW__CORE__SQL_ALCHEMY_CONN"]="postgresql+psycopg2://airflow_user:airflow_pass@localhost:5432/airflow_db"
    ["AIRFLOW__DATABASE__SQL_ALCHEMY_CONN"]="postgresql+psycopg2://airflow_user:airflow_pass@localhost:5432/airflow_db"
    ["AIRFLOW__CELERY__BROKER_URL"]="$REDIS_URL"
)

# Export the variables if they are set
for key in "${!airflow_variables[@]}"; do
    if [[ -n "${airflow_variables[$key]}" ]]; then
        export "$key"="${airflow_variables[$key]}"
        echo "$key"="${airflow_variables[$key]}" >> ~/.bashrc
    fi
done

# Switch from default SQLite to postgres
# airflow db migrate

# FIXME: use only default credentials or let user choose?
# Create an airflow webserver user
airflow users create \
 --username "$USERNAME" \
 --firstname FIRST_NAME \
 --lastname LAST_NAME \
 --role Admin \
 --password "$PASSWORD"  \
 --email admin@example.org        
 
# Start Airflow
#airflow webserver --port "$PORT" &
#airflow scheduler &

#sleep infinity
