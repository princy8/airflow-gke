FROM python:3.6

ENV AIRFLOW_GPL_UNIDECODE=yes
ENV CONFIG /root/.config/gcloud
ENV PATH /root/google-cloud-sdk/bin:$PATH
ENV AIRFLOW_HOME /airflow
ENV AIRFLOW_CONFIG $AIRFLOW_HOME/airflow.cfg
ENV AIRFLOW_USER airflow
#---set your environment
ENV GCPKEY=
ENV GCPSERVICEACCOUNT=
ENV GCPPROJECT=
ENV DAG_REPOSITORY=
#---

RUN apt update \
    && apt-get -y install \
                  sudo \
                  lhasa \
                  vim \
                  curl \
                  nmap \
                  netcat\
    && pip install \
                  redis \
                  celery \
                  psycopg2 \
                  apache-airflow \
                  apache-airflow[postgres] \
                  apache-airflow[celery] \
                  apache-airflow[gcp_api] \
                  flask_bcrypt \
                  google-api-python-client \
                  pandas_gbq\
    && useradd -ms /bin/bash -d ${AIRFLOW_HOME} ${AIRFLOW_USER} \
    && curl https://sdk.cloud.google.com | bash    

ADD config/airflow.cfg ${AIRFLOW_HOME}
ADD script/user_register.py ${AIRFLOW_HOME}
ADD keyfile/${GCPKEY} ${CONFIG}/${GCPKEY}
ADD script/entrypoint.sh ${AIRFLOW_HOME}

RUN gcloud auth activate-service-account ${GCPSERVICEACCOUNT} --key-file $CONFIG/${GCPKEY} --project ${GCPPROJECT}

WORKDIR ${AIRFLOW_HOME}

RUN gcloud source repos clone ${DAG_REPOSITORY} --project=${GCPPROJECT}

RUN chmod -R 755 ${AIRFLOW_HOME}
RUN chown -R ${AIRFLOW_USER}: ${AIRFLOW_HOME}
RUN chown -R ${AIRFLOW_USER}: /root
RUN echo "%${AIRFLOW_USER} ALL=NOPASSWD: ALL" >> /etc/sudoers

USER ${AIRFLOW_USER}

ENTRYPOINT ["./entrypoint.sh"]