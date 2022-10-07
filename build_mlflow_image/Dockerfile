FROM ubuntu:20.04
MAINTAINER Ben Wang

RUN apt -y update && apt install -y software-properties-common
RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt -y update
RUN apt -y install python3.9 python3-pip python3.9-distutils --no-install-recommends
RUN python3.9 -m pip install pip setuptools distlib --upgrade
RUN pip install mlflow pymysql


RUN cd ~ && mkdir -p mlflow-tracking-server && mkdir -p mlflow-tracking-server/mlruns
WORKDIR /root/mlflow-tracking-server

