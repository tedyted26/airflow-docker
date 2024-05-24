FROM dreg.cloud.sdu.dk/ucloud-apps/conda:24.1.2.0

USER 0

## Install Redis
RUN apt-get update \
 && apt-get install -y --no-install-recommends redis-server \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

ENV DEBIAN_FRONTEND=noninteractive

## Install PostgreSQL
RUN apt-get -y update \
 && apt-get install -y --no-install-recommends postgresql postgresql-client postgresql-client-common postgresql-contrib \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && pip install --no-cache-dir --upgrade pip \
 ## PostgreSQL adapter for Python
 && pip install --no-cache-dir psycopg2-binary \
 && chown -R "$USERID":"$GROUPID" /var/run/postgresql 

COPY --chown="$USERID":"$GROUPID" start_app.sh /usr/local/bin/start_app
COPY --chown="$USERID":"$GROUPID" wait-for-postgres.sh /usr/local/bin/wait-for-postgres

## Install Airflow and sudo/pip requirements
## Python version = 3.10
## Airflow version = 2.8.3
ENV AIRFLOW_HOME="/work/Airflow"

# Dependencies for Airflow providers
RUN apt-get -y update && apt-get install python3-dev libmysqlclient-dev build-essential pkg-config libldap2-dev libsasl2-dev unixodbc -y

USER $USERID

# Pip dependencies for Airflow providers
RUN pip install mysqlclient

#cncf-kubernetes and docker are removed from the default list
RUN pip install "apache-airflow[aiobotocore,amazon,async,celery,common-io,elasticsearch,fab,ftp,google,google-auth,graphviz,grpc,hashicorp,http,ldap,microsoft-azure,mysql,odbc,openlineage,pandas,postgres,redis,sendgrid,sftp,slack,snowflake,ssh,statsd,swagger-ui,uv,virtualenv]==2.8.3" \
--constraint "https://raw.githubusercontent.com/apache/airflow/constraints-2.8.3/constraints-3.10.txt"

WORKDIR /work

RUN chmod +x /usr/local/bin/start_app
RUN chmod +x /usr/local/bin/wait-for-postgres

ENTRYPOINT /usr/local/bin/start_app
