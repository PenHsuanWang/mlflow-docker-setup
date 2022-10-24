#!bin/bash

set -m

sudo mlflow server --artifacts-destination ./mlartifacts --gunicorn-opts "--log-level debug" --serve-artifacts --artifacts-only --host 0.0.0.0 --port 5500 &

sudo mlflow server --backend-store-uri mysql+pymysql://'mlflow':'mlflow'@db:3306/mlflowruns --default-artifact-root http://127.0.0.1:5500/api/2.0/mlflow-artifacts/artifacts/experiments --gunicorn-opts "--log-level debug" --host 0.0.0.0 --port 5000



# mlflow ui --backend-store-uri mysql+pymysql://'mlflow':'mlflow'@db:3306/mlflowruns --default-artifact-root ./mlruns --host 0.0.0.0 --port 5000

fg %1
