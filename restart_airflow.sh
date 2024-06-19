#!/bin/bash

# Stop Airflow webserver and scheduler
stop_airflow() {
    echo "\tStopping Airflow webserver..."
    pkill -f "airflow webserver"
    echo "\tStopping Airflow scheduler..."
    pkill -f "airflow scheduler"
}

# Start Airflow webserver and scheduler
start_airflow() {
    echo "\tStarting Airflow webserver..."
    airflow webserver & # or maybe use nohup and redirect output to a log file 
    # nohup airflow webserver > /work/airflow_webserver.log 2>&1 &
    echo "\tStarting Airflow scheduler..."
    aiflow scheduler & 
    # nohup airflow scheduler > /work/airflow_scheduler.log 2>&1 &

}

echo "Restarting Airflow..."
stop_airflow
sleep 5
start_airflow
echo "Airflow restarted successfully!"