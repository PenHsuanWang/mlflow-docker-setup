# MLflow Tracking Server with MySQL Backend and Artifact Server

This project sets up a complete MLflow infrastructure using Docker Compose. The setup includes a MySQL database to store experiment metadata, an MLflow Tracking Server to manage and log machine learning experiments, and an MLflow Artifact Server to handle the storage of large artifacts like models and datasets. The infrastructure is containerized using Docker, ensuring a consistent, scalable, and maintainable environment for managing machine learning workflows.

## Architecture Overview

The architecture consists of the following components:

1. **MySQL Database (`db`)**: 
   - Acts as the backend store for MLflow, persisting all experiment metadata such as run parameters, metrics, and results.
   - The MySQL service runs in a Docker container, with data persistently stored on the host machine to ensure durability.

2. **MLflow Tracking Server (`mlflow`)**: 
   - The central service for logging and managing machine learning experiments. It stores metadata in the MySQL database and manages links to artifacts stored on the Artifact Server.
   - The Tracking Server is accessible via HTTP and provides a web interface and REST API for experiment management.

3. **MLflow Artifact Server (`mlflow-artifact-server`)**: 
   - Dedicated server for storing and serving large artifacts produced during ML experiments. Artifacts are stored persistently on the host machine.
   - The Artifact Server operates independently from the Tracking Server, providing scalability and separation of concerns.

### Docker Compose Services

- **`db`**: 
  - **Image**: `mysql`
  - **Ports**: `3316:3306` (Maps MySQL's default port 3306 to 3316 on the host)
  - **Environment Variables**:
    - `MYSQL_ROOT_PASSWORD`: Root password for MySQL (should be set in your environment file).
  - **Volumes**:
    - `./my.cnf` is bind-mounted to `/etc/my.cnf` inside the container to customize MySQL configurations.
    - MySQL data is stored persistently in `~/container_volume_persist/mysql-data-persist` on the host.

- **`mlflow-artifact-server`**:
  - **Build**: The service is built from a local `Dockerfile`.
  - **Ports**: `5500:5500` (Exposes the Artifact Server on port 5500).
  - **Command**: 
    - Runs the MLflow server in artifact-only mode, serving artifacts from a local directory.
  - **Volumes**:
    - Artifacts are stored persistently in `~/container_volume_persist/artifact-data-persist` on the host.

- **`mlflow`**:
  - **Build**: The service is built from a local `Dockerfile`.
  - **Ports**: `5011:5001` (Exposes the MLflow Tracking Server on port 5001).
  - **Environment**: Configuration is loaded from a `.env` file.
  - **Command**:
    - Starts the MLflow server with the MySQL backend and links to the Artifact Server for storing experiment results.

### Network Configuration

- **`shared_network`**:
  - The services communicate over a shared external Docker network, allowing seamless interaction between the MySQL database, MLflow Tracking Server, and Artifact Server.

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
