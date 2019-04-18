# GKEへデプロイ
## GKEクラスタ立ち上げ
「airflow-gke」というクラスタを立ち上げる
以下は、g1-smallの10GBディスクでus-central1-aゾーンに3ノード構成でクラスタを作成するサンプルコマンド。

```:サンプル
gcloud container clusters create airflow-gke --machine-type=g1-small --num-nodes=3 --disk-size=10 --zone=us-central1-a
```

preemptibleにする場合は、「--preemptible」オプションを追加すればよい

## kubectlの認証情報の設定
kubernetesクラスタは基本的に「kubectl」コマンドで操作するが、
どのクラスタに対してのコマンド発行なのかを認証する

```
gcloud container clusters get-credentials airflow-gke --zone=us-central1-a
```


## リモートリポジトリのclone
任意のディレクトリで以下実行

```git
git clone https://github.com/yakamazu/airflow-gke.git
```

## Source RepositoriesでDag用のリポジトリを作成
詳細割愛

## ログ用のGCSバケットを作成
詳細割愛
任意のログ用バケットを作成する。

## サービスアカウントの作成、keyfileの配置
詳細割愛
keyfileはgcsにアップしてgsutil使ってcloudshell環境に持っていく等。

## Dockerfileの修正
---set your environmentの部分

ENV GCPKEY：サービスアカウントのキーファイル名

ENV GCPSERVICEACCOUNT：サービスアカウント名

ENV GCPPROJECT：GCPプロジェクトID

ENV DAG_REPOSITORY：SourceRepositoriesのDAGのリポジトリ名

ENV AIRFLOW_LOGIN_USER：AirflowのWebUIログインユーザー

ENV AIRFLOW_LOGIN_PASS：AirflowのWebUIログインパスワード

ENV AIRFLOW_FIRSTNAME：AirflowのWebUIログインユーザー表示名（名）

ENV AIRFLOW_LASTNAME：AirflowのWebUIログインユーザー表示名（姓）

ENV AIRFLOW_EMAIL：AirflowのWebUIログインユーザーのメールアドレス


## configファイルの修正
諸々のファイル類の部分で記載したconfigを修正する。
特にログのGCSの場所と、メール情報

### ディレクトリの指定、GCSの指定

```config
[core]
# The home folder for airflow, default is ~/airflow
airflow_home = /airflow #ホームディレクトリ

# The folder where your airflow pipelines live, most likely a
# subfolder in a code repository
# This path must be absolute
dags_folder = /airflow/dags #Dagのディレクトリ

# The folder where airflow should store its log files
# This path must be absolute
base_log_folder = /airflow/logs #logのディレクトリ

# Airflow can store logs remotely in AWS S3, Google Cloud Storage or Elastic Search.
# Users must supply an Airflow connection id that provides access to the storage
# location. If remote_logging is set to true, see UPDATING.md for additional
# configuration requirements.
remote_logging = True #ログをGCSに置くのでTrue
remote_log_conn_id = airflow_gcp #GCPへのコネクションID entrypoint.shにて設定
remote_base_log_folder = gs:// #ログを出力するgcsバケット
encrypt_s3_logs = False
```

### エラー時のメール送信元設定

```config
[smtp]
# If you want airflow to send emails on retries, failure, and you want to use
# the airflow.utils.email.send_email_smtp function, you have to configure an
# smtp server here
smtp_host = smtp.gmail.com #gmailのsmtpサーバ
smtp_starttls = True
smtp_ssl = False
smtp_user =  #ログインユーザ
smtp_password = #ログインパス（アプリパスワードなので注意！）
# Uncomment and set the user/pass settings if you want to use SMTP AUTH
# smtp_user = airflow
# smtp_password = airflow
smtp_port = 587 #gmailのsmtpサーバのポート
smtp_mail_from =  #送信元メールアドレス
```

## entrypoint.shの修正
connecitonsを作成する部分の{keyfilename}と{gcp_projectid}はそれぞれ、サービスアカウントのkeyfile名とgcpのプロジェクトIDに置き換える。

```
$CMD connections --add --conn_id=airflow_gcp --conn_type=google_cloud_platform --conn_extra='{"extra__google_cloud_platform__key_path":"/root/.config/gcloud/{keyfilename}","extra__google_cloud_platform__project":"{gcp_projectid}","extra__google_cloud_platform__scope":"https://www.googleapis.com/auth/cloud-platform"}'
```

## Dockerイメージの作成
Dockerfileが格納されているディレクトリで以下コマンド実行。
airflow-gkeというイメージが作成される。

```
docker image build -t asia.gcr.io/プロジェクトID/airflow-gke:latest .
```

## Container RegistryへのPush
docker push 使うための認証

```
gcloud auth configure-docker
```

Container RegistryへのPush

```
docker push asia.gcr.io/プロジェクトID/airflow-gke:latest
```

## airflow_deploy.yamlの修正
deploymentのwebserverとschedulerとworkerに関しては、コンテナレジストリにPushしたイメージIDを上書きする。
「image」の#container imageのところを「asia.gcr.io/プロジェクトID/airflow-gke:latest」にする。

## airflow_deploy.yamlのapply
以下コマンドの実行

```
kubectl apply -f airflow_deploy.yaml
```

## Ingressに固定IPを設定する
[こちら](https://cloud.google.com/kubernetes-engine/docs/tutorials/http-balancer?hl=ja#step_5_optional_configuring_a_static_ip_address)参考にingress_airflow.yamlのglobal-static-ip-nameと名前を合わせた固定IPを作成する。

```
gcloud compute addresses create airflow-ingress-ip --global
```

## ingress_airflow.yamlのapply
以下コマンドの実行
※起動するとロードバランサー立ち上がり、料金かかる

```
kubectl apply -f ingress_airflow.yaml
```
