#!/bin/bash

# Delete this
start=$(date +%s)

sudo apt update

# Needed for mysql
sudo apt-get install python3-dev default-libmysqlclient-dev build-essential pkg-config -y
pip install mysqlclient

# Install and activate vitual environment
pip install virtualenv
mkdir /work/v_airflow
cd /work/v_airflow
virtualenv air
source air/bin/activate
echo "source /work/v_airflow/air/bin/activate" >> ~/.bashrc

# Install airflow and set AIRFLOW_HOME to be inside of /work, that way the configuration file and the dags persist after the job ends
echo "export AIRFLOW_HOME=/work/Airflow" >> ~/.bashrc
export AIRFLOW_HOME=/work/Airflow
# Create the airflow home folder so we can import the configuration file and the dags folder so its easier to start working
mkdir -p /work/Airflow/dags
# Other environment variables
echo "export AIRFLOW__CORE__LOAD_EXAMPLES=False" >> ~/.bashrc
export AIRFLOW__CORE__LOAD_EXAMPLES=False

AIRFLOW_VERSION=2.8.3

# Extract the version of Python you have installed
PYTHON_VERSION="$(python --version | cut -d " " -f 2 | cut -d "." -f 1-2)"
# PYTHON_VERSION=3.10 

CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"


pip install "apache-airflow[postgres,mysql,celery,spark]==${AIRFLOW_VERSION}" --constraint "${CONSTRAINT_URL}"

# Dependencies
# Check if this is needed
# pip install "apache-airflow==${AIRFLOW_VERSION}" connexion[swagger-ui]

# # Providers
# pip install "apache-airflow==${AIRFLOW_VERSION}" apache-airflow-providers-postgres[amazon]
# pip install "apache-airflow==${AIRFLOW_VERSION}" apache-airflow-providers-mysql[amazon]

# Activate argcomplete
register-python-argcomplete airflow >> ~/.bashrc

# This is custom only for this script - comment one of the connections (MYSQL or Postgres)
# CONNECTION TO POSTGRESQL
# echo "export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow_user:airflow_pass@postgres/airflow_db" >> ~/.bashrc
# export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow_user:airflow_pass@postgres/airflow_db

# CONNECTION TO MYSQL
# echo "export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=mysql+mysqldb://airflow_user:airflow_pass@mysql/airflow_db" >> ~/.bashrc
# export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=mysql+mysqldb://airflow_user:airflow_pass@mysql/airflow_db

airflow config get-value database sql_alchemy_conn # Check that value is ok
airflow db migrate # Switch from SQLite to postgres
# Create an airflow user
airflow users create \
 --username admin \
 --firstname Admin \
 --lastname Admin \
 --role Admin \
 --email admin@admin.com \
 --password admin

# Now webserver can be started after using $ nginx -s stop with:
# $ airflow webserver —port 8080
# $ airflow scheduler

# Create a connection to the db
# POSTGRESQL
# In postgresql, the public schema will contain the airflow_db created in the server
airflow connections add 'postgres' \
    --conn-type 'postgres' \
    --conn-login 'airflow_user' \
    --conn-password 'airflow_pass' \
    --conn-host 'postre' \
    --conn-port '5432' \
    --conn-schema 'public'
# MYSQL
# In MySQL, schema and db are interchangable, so we specify the database
airflow connections add 'mysql' \
    --conn-type 'mysql' \
    --conn-login 'airflow_user' \
    --conn-password 'airflow_pass' \
    --conn-host 'mysql' \
    --conn-port '3306' \
    --conn-schema 'airflow_db'
#SPARK
airflow connections add 'spark' \
    --conn-type 'spark' \
    --conn-host 'spark://spark-master' \
    --conn-port '7077'

# Delete this
end=$(date +%s)
duration=$((end - start))
echo "Script execution time: $duration seconds"

