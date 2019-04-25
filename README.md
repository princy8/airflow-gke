# Premise
using cloud shell

# Deploy to GKE
## GKE cluster launch
Launch a cluster called "airflow-gke"
The following is a sample command to create a 3-node cluster in the us-central1-a zone with a 10-GB g1-small disk.

```:sample
gcloud container clusters create airflow-gke --machine-type=g1-small --num-nodes=3 --disk-size=10 --zone=us-central1-a
```

To make it preemptible, add the "--preemptible" option

## Setting kubectl authentication information
Authenticate "kubectl" command

```
gcloud container clusters get-credentials airflow-gke --zone=us-central1-a
```


## Remote repository clone
Execute the following in any directory

```git
git clone https://github.com/yakamazu/airflow-gke.git
```

## Create Repositories for Dag with Source Repositories
Detail omission

## Create a GCS bucket for logs
Detail omission
Create any log buckets.

## Creation of service account and placement of keyfile
Detail omission

## Fix Dockerfile
---part of set your environment

ENV GCPKEY：Service account key file name

ENV GCPSERVICEACCOUNT：Service account name

ENV GCPPROJECT：GCP project ID

ENV DAG_REPOSITORY：Repository name of SourceRepositories DAG

ENV AIRFLOW_LOGIN_USER：Airflow WebUI login user

ENV AIRFLOW_LOGIN_PASS：Airflow WebUI Login Password

ENV AIRFLOW_FIRSTNAME：Airflow Web UI login user display name (first name)

ENV AIRFLOW_LASTNAME：Airflow Web UI login user display name (surname)

ENV AIRFLOW_EMAIL：Airflow Web UI login user email address


## Modify config file
Especially the location of the log GCS and email information

### Directory specification, GCS specification

```config
[core]
# The home folder for airflow, default is ~/airflow
airflow_home = /airflow 

# The folder where your airflow pipelines live, most likely a
# subfolder in a code repository
# This path must be absolute
dags_folder = /airflow/dags 

# The folder where airflow should store its log files
# This path must be absolute
base_log_folder = /airflow/logs 

# Airflow can store logs remotely in AWS S3, Google Cloud Storage or Elastic Search.
# Users must supply an Airflow connection id that provides access to the storage
# location. If remote_logging is set to true, see UPDATING.md for additional
# configuration requirements.
remote_logging = True 
remote_log_conn_id = airflow_gcp 
remote_base_log_folder = gs:// #GCS bucket to output log
encrypt_s3_logs = False
```

### Mail sender setting at error

```config
[smtp]
# If you want airflow to send emails on retries, failure, and you want to use
# the airflow.utils.email.send_email_smtp function, you have to configure an
# smtp server here
smtp_host = smtp.gmail.com 
smtp_starttls = True
smtp_ssl = False
smtp_user =  #Login user
smtp_password = #Login pass (it is an app password!)
# Uncomment and set the user/pass settings if you want to use SMTP AUTH
# smtp_user = airflow
# smtp_password = airflow
smtp_port = 587 
smtp_mail_from =  #email address
```

## Modification of entrypoint.sh
Replace {keyfilename} and {gcp_projectid} in the part to create connecitons with the keyfile name of the service account and the project ID of gcp, respectively.

```
$CMD connections --add --conn_id=airflow_gcp --conn_type=google_cloud_platform --conn_extra='{"extra__google_cloud_platform__key_path":"/root/.config/gcloud/{keyfilename}","extra__google_cloud_platform__project":"{gcp_projectid}","extra__google_cloud_platform__scope":"https://www.googleapis.com/auth/cloud-platform"}'
```

## Create Docker image
Execute the following command in the directory where Dockerfile is stored.
An image called airflow-gke is created.

```
docker image build -t asia.gcr.io/{your project ID}/airflow-gke:latest .
```

## Push to Container Registry
Authentication to use docker push

```
gcloud auth configure-docker
```

Push to Container Registry

```
docker push asia.gcr.io/{your project ID}/airflow-gke:latest
```

## Modify airflow_deploy.yaml
For deployment's webserver, scheduler, and worker, overwrite the image ID pushed in the container registry.
Set "#container image" of "image" to "asia.gcr.io/{your project ID}/airflow-gke: latest".

## Apply airflow_deploy.yaml

```
kubectl apply -f airflow_deploy.yaml
```

## Set fixed IP to Ingress

```
gcloud compute addresses create airflow-ingress-ip --global
```

## Apply ingress_airflow.yaml

```
kubectl apply -f ingress_airflow.yaml
```
