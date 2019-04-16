#!/usr/bin/env bash

CMD="airflow"
TRY_LOOP="${TRY_LOOP:-10}"
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT=5432
REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_PORT=6379

echo "Postgres host: $POSTGRES_HOST"
echo "Redis host: $REDIS_HOST"

# set gcp connections
$CMD connections --add --conn_id=airflow_gcp --conn_type=google_cloud_platform --conn_extra='{"extra__google_cloud_platform__key_path":"/root/.config/gcloud/{keyfilename}","extra__google_cloud_platform__project":"{gcp_projectid}","extra__google_cloud_platform__scope":"https://www.googleapis.com/auth/cloud-platform"}'

# wait for postgres
if [ "$1" = "webserver" ] || [ "$1" = "worker" ] || [ "$1" = "scheduler" ] ; then
  i=0

  while [ `sudo nping --tcp $POSTGRES_HOST -p $POSTGRES_PORT | grep -i Rcvd: | sed s/^.*Rcvd:// | sed s/\(.*// | tr -d ' '` -eq 0 ] 
  do
    i=`expr $i + 1`
    if [ $i -ge $TRY_LOOP ]; then
      echo "$(date) - ${POSTGRES_HOST}:${POSTGRES_PORT} still not reachable, giving up"
      exit 1
    fi
    echo "$(date) - waiting for ${POSTGRES_HOST}:${POSTGRES_PORT}... $i/$TRY_LOOP"
    sleep 5
  done
  
  # initdb and register user
  if [ "$1" = "webserver" ]; then
    echo "Initialize database..."
    $CMD upgradedb

    echo "Register user..."
    $CMD create_user -r Admin -u ${AIRFLOW_LOGIN_USER} -p ${AIRFLOW_LOGIN_PASS} -f ${AIRFLOW_FIRSTNAME} -l ${AIRFLOW_LASTNAME} -e ${AIRFLOW_EMAIL}
  fi
fi

# wait for redis
if [ "$1" = "webserver" ] || [ "$1" = "worker" ] || [ "$1" = "scheduler" ] ; then
  j=0

  while [ `sudo nping --tcp $REDIS_HOST -p $REDIS_PORT | grep -i Rcvd: | sed s/^.*Rcvd:// | sed s/\(.*// | tr -d ' '` -eq 0 ] 
  do
    j=`expr $j + 1`
    if [ $j -ge $TRY_LOOP ]; then
      echo "$(date) - ${REDIS_HOST}:${REDIS_PORT} still not reachable, giving up"
      exit 1
    fi
    echo "$(date) - waiting for ${REDIS_HOST}:${REDIS_PORT}... $j/$TRY_LOOP"
    sleep 5
  done
fi

#git clone dags
gcloud auth activate-service-account ${GCPSERVICEACCOUNT} --key-file $CONFIG/${GCPKEY} --project ${GCPPROJECT}
gcloud source repos clone ${DAG_REPOSITORY} --project=${GCPPROJECT}

#execute args
$CMD "$@"