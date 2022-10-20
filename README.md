# mlflow tracking server build up

To build up mlflow tracking server dependents MySQL DB backend store.
Accomplish iwth `docker-compose` defining container running db and mlflow.

The `build_mysql_image/Dockerfile` defining the MySQL docker image build process, from official ubuntu/mysql base image.
create user/passward

The `build_mlflow_image/Dockerfile` defining the MLFlow docker image build process. Install python3.9 and mlflow together with dependenecy.
Start mlflow tracking server which using `db` services as backend store. Running mlflow ui as well.

## Usage

docker-compose build
docker-compose up

