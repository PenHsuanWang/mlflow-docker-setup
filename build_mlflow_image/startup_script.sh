#!bin/bash

set -m

mlflow server --backend-store-uri mysql+pymysql://'mlflow':'mlflow'@db:3306/mlflowruns --default-artifact-root ./mlruns --host 0.0.0.0 --port 8080 &

mlflow ui --backend-store-uri mysql+pymysql://'mlflow':'mlflow'@db:3306/mlflowruns --default-artifact-root ./mlruns --host 0.0.0.0 --port 5000

fg %1
