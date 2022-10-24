# Overview

We are doing wonderful jobs on model training and now we are facing the problem in the next stage.  
How to launch ML Services and go production gracefully? 
That is the point why we are seeking do the solution called Model Ops or MLOps. The availability to do Run to Run compare, Version control, Model Stagging, and Rollback should be put on the table for consideration.  

### What we are going to do.

* Using MLFlow Tracking Server for model versioning control and experiment tracing.
* Build MLFlow Tracking Server affiliate with MySQL backend-store by `docker-compose`
* Doing Model training using python code, and regist to mlflow tracking server.
* Using `mlflow models serve` to run MLFlow tracking server and artifact server.



# Hands-on

實作架構

![](https://i.imgur.com/wfVeUdS.png)

ML 模型訓練由本地端的 python 專案負責。
通過 MLFlow Client 連至運行於 docker container 內的 MLFlow Tracking Server.

MLFlow Tracking Server 使用 MySQL backend store 儲存模型訓練實驗相關的資料。
MLFlow Tracking Server 使用 local file Artifact Server 儲存 model / data 等大型物件。


#### APP

* Tracking Server & Artifact Server 使用 python3.7 的 base image 作為基底。再安裝 mlflow 以及 pymysql 套件。
* MySQL 使用官方提供的 based image

docker compose file 的完整設置

```yaml!
version: '3.9'
services:
  db:
    image: mysql
    environment:
      TZ: UTC
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: mlflowruns
      MYSQL_USER: mlflow
      MYSQL_PASSWORD: mlflow
    ports:
      - "3316:3306"

  mlflow-artifact-server:
    build: .
    expose:
      - "5500"
    ports:
      - "5500:5500"
    command: >
      mlflow server
      --host 0.0.0.0
      --port 5500
      --artifacts-destination ./mlartifacts
      --gunicorn-opts "--log-level debug"
      --serve-artifacts
      --artifacts-only
    
  mlflow:
    tty: true
    build: .
    ports:
      - "5010:5000"
    depends_on:
      db:
        condition: service_started

    command: >
      mlflow server
      --host 0.0.0.0
      --port 5000
      --backend-store-uri mysql+pymysql://'mlflow':'mlflow'@db:3306/mlflowruns
      --default-artifact-root http://127.0.0.1:5500/api/2.0/mlflow-artifacts/artifacts/experiments
      --gunicorn-opts "--log-level debug"
```

Docker file for run mlflow serve

```dockerfile!
FROM python:3.7

WORKDIR /app

# Install mlflow
RUN pip install mlflow pymysql cryptography
```


# Workflow:

Using `docker-compose`  
you can fetch the docker-compose build files from my github  

```
git clone https://github.com/PenHsuanWang/mlflow-docker-setup.git && cd mlflow-docker-setup
```

build and start up the docker compose

```
docker-compose build
docker-compose up
```

![](https://i.imgur.com/fVQiEiN.png)



check the docker container is running 🐳

```
docker ps --format "{{.Names}}\t{{.Status}}"
```

![](https://i.imgur.com/IZzmKUP.png)

the artifact server is running.
![](https://i.imgur.com/JzlgXQr.png)

the tracking server is running as well
![](https://i.imgur.com/4PZ9he6.png)

Every thing is up. Let's move to python code.  

### Connect to tracking server from python project

using mlflow api `set_tracking_uri(<url of tracking server>)` to connect to tracking server.

![](https://i.imgur.com/sqF8jdA.png)

![](https://i.imgur.com/ofw6yBM.png)


### Saving the ML Experiment log/metrics/metadata at `db` container (mysql)

Onec we start to run the ml model training experiment. if we using mlflow.model.autolog() inside the `mlflow.start_run()` context manager block, the model will be log into tracking server (using mysql db as backend store).
Check the mysql db.

The experiment metadata will be saved in `mlflowruns`

![](https://i.imgur.com/qnVXOFw.png)

![](https://i.imgur.com/XVIdXBH.png)

![](https://i.imgur.com/qzeGKY1.png)  

### Check Experiment from mlflow UI
connect to mlflow server (where we start server at port 5000 in the container, but we expose to 5010 port on localhost.)

connect to : http://127.0.0.1:5010

![](https://i.imgur.com/yxgUWds.png)

check the experiment we create from python code 
![](https://i.imgur.com/1Mpy6Q5.png)

you can check the metrics logged during the experiemnt, e.g. loss.

![](https://i.imgur.com/shpvexG.png)

check the corresponding model registered from experiment.

![](https://i.imgur.com/YXLGg9d.png)

![](https://i.imgur.com/tHUqCzy.png)

### Deploy MLFlow Model Serving at local REST endpoint

[official docs.](https://www.mlflow.org/docs/latest/models.html#deploy-mlflow-models)


1. setting mlflow server url.
```export MLFLOW_TRACKING_URI=http://127.0.0.1:5010```

2. start mlflow models serve.
```mlflow models serve --no-conda -m <model uri>/<Stage>```
e.g. 
```mlflow models serve --no-conda -m "models:/power-forecasting-model/Production"```

![](https://i.imgur.com/RatmSG8.png)

3. send testing data for inference.

provided endpoint:
> The REST API defines 4 endpoints:
> 
> /ping used for health check
> /health (same as /ping)
> /version used for getting the mlflow version
> /invocations used for scoring

e.g.
```
curl http://127.0.0.1:5000/invocations -X POST -H 'Content-Type: application/json' \
-d '[{"temperature_00": 8.875944, "wind_direction_00": 97.246960, "wind_speed_00":11.665322, "temperature_08": 11.955358, "wind_direction_08": 98.636955, "wind_speed_08": 12.240791, "temperature_16": 14.668171, "wind_direction_16": 112.411930, "wind_speed_16": 9.737414}]'
```
![](https://i.imgur.com/rehZkDe.png)


### serving by docker

[official docs](https://www.mlflow.org/docs/latest/cli.html#mlflow-models-build-docker)

```mlflow models build-docker --model-uri "models:/power-forecasting-model/Production" --name "power-forecast-model-seving"```

![](https://i.imgur.com/lB2rE1F.png)

start docker container
```docker run -p 5001:8080 "power-forecast-model-seving"```

![](https://i.imgur.com/LfpA6lO.png)

invoking `http://127.0.0.1:5001/invocations` for model prediction

```
curl http://127.0.0.1:5001/invocations -X POST -H 'Content-Type: application/json' \
-d '[{"temperature_00": 8.875944, "wind_direction_00": 97.246960, "wind_speed_00":11.665322, "temperature_08": 11.955358, "wind_direction_08": 98.636955, "wind_speed_08": 12.240791, "temperature_16": 14.668171, "wind_direction_16": 112.411930, "wind_speed_16": 9.737414}]'
```
![](https://i.imgur.com/2qhajLi.png)

