# Overview

This project sets up a complete MLflow infrastructure using Docker Compose. The setup includes a MySQL database to store experiment metadata, an MLflow Tracking Server to manage and log machine learning experiments, and an MLflow Artifact Server to handle the storage of large artifacts like models and datasets. The infrastructure is containerized using Docker, ensuring a consistent, scalable, and maintainable environment for managing machine learning workflows.

## Create MySQL user and user databases for mlflow experiment:

initialization of environment file
```bash
cat <<EOT >> .env
MYSQL_ROOT_PASSWORD=root
EOT
```

```bash
docker compose build
docker compose up
```

```bash
docker exec -it backend-storage-db-1 bash
```

```bash
mysql -u root -p 
```
privode password settinf from .env (in this example is  `root`)

create user and correspoding databases
```bash
CREATE USER '<user>'@'%' IDENTIFIED WITH mysql_native_password BY '<passwd>';
CREATE DATABASE IF NOT EXISTS <databases_name> CHARACTER SET utf8;
GRANT SELECT,INSERT,CREATE,ALTER,DROP,LOCK TABLES,CREATE TEMPORARY TABLES, DELETE, UPDATE, EXECUTE, INDEX, REFERENCES ON <databases_name>.* TO '<user>'@'%';
```
