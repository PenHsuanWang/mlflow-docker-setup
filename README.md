# Hands-on, In the nut-shell

pre-request

makesure docker is installed and docker engine is running

```
git clone https://github.com/PenHsuanWang/mlflow-docker-setup.git && cd mlflow-docker-setup 

docker create network mlflow-tracking-server-network  
docker-compose build  
docker-compose up  

```

check container is running

```
docker ps --format "{{.Names}}\t{{.Status}}"
```

![](https://i.imgur.com/n9cNPqM.png)

## After start up docker compose

connect to 
http://127.0.0.1:5010 for check


MLFlow Tracking Server will running on port 8080 and export to 8090
MLFlow UI will running on port 5000 and export to 5010

In the nutshell.
From ML training code-base. regist to <your server ip>:8090. e.g. http://127.0.0.1:8090 if your project is at the host
Connect to UI. <your server ip>:5010. e.g. http://127.0.0.1:5010

![](https://i.imgur.com/4HiepDj.png)

Connect to MLFlow UI
![](https://i.imgur.com/OJ5GNLv.png)

To learn more.

# mlflow tracking server build up

Setting up the MLFlow with manually backend-store tracking server.
referance : [Scenario 3 : MLFlow on localhost with Tracking Server](https://www.mlflow.org/docs/latest/tracking.html#scenario-3-mlflow-on-localhost-with-tracking-server)

![](https://i.imgur.com/fXobd7l.png)

To build up mlflow tracking server dependents MySQL DB backend store.
Accomplish iwth `docker-compose` defining container running db and mlflow.

The `build_mysql_image/Dockerfile` defining the MySQL docker image build process, from official ubuntu/mysql base image.
create user/passward

The `build_mlflow_image/Dockerfile` defining the MLFlow docker image build process. Install python3.9 and mlflow together with dependenecy.
Start mlflow tracking server which using `db` services as backend store. Running mlflow ui as well.





