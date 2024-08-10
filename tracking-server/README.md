# MLflow Tracking Server with MySQL Backend, Artifact Server, and NGINX Reverse Proxy

This project sets up a complete MLflow infrastructure using Docker Compose, enhanced with NGINX as a reverse proxy to secure and manage traffic to the MLflow Tracking Server. The setup includes a MySQL database to store experiment metadata, an MLflow Tracking Server to manage and log machine learning experiments, an MLflow Artifact Server to handle the storage of large artifacts like models and datasets, and an NGINX server to route and protect traffic.

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

4. **NGINX Reverse Proxy (`nginx`)**: 
   - NGINX acts as a reverse proxy, routing incoming traffic to the appropriate service (MLflow Tracking Server) and providing an additional layer of security.
   - It helps in managing traffic, securing the endpoints, and enabling future enhancements like SSL termination or load balancing.

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

- **`nginx`**:
  - **Build**: The service is built from a custom NGINX Dockerfile located in the `build-nginx/` directory.
  - **Ports**: `7777:80` (Exposes NGINX on port 7777 on the host, which then forwards requests to the MLflow Tracking Server).
  - **Volumes**:
    - `nginx.conf` is bind-mounted to `/etc/nginx/nginx.conf` inside the container to customize NGINX configurations.
    - `webserver.sh` is used to manage and start the NGINX server, ensuring the MLflow service is up before NGINX starts routing traffic.
  - **Depends On**: The NGINX service depends on the MLflow service, ensuring that the reverse proxy only starts once the MLflow server is up and running.

### Network Configuration

- **`shared_network`**:
  - The services communicate over a shared external Docker network, allowing seamless interaction between the MySQL database, MLflow Tracking Server, Artifact Server, and NGINX.


before starting docker compose
create env file
```
cat <<EOT >> .env
MLFLOW_BACKEND_DB_USERNAME=<db_username>
MLFLOW_BACKEND_DB_PASSWORD=<db_password>
MLFLOW_BACKEND_DB=<db_name>
MLFLOW_BACKEND_URL=<mlflow backend url>
MLFLOW_TRACKING_INSECURE_TLS=false
MLFLOW_TRACKING_USERNAME=<mlflow_username>
MLFLOW_TRACKING_PASSWORD=<mlflow_password>
EOT
```

starting docker compose
```
docker compose build
docker compose up
```

## Connect to mlflow tracking server ui

Here using nginx as proxy server to do passing traffic.
Connect to nginx : `http://localhost:7777`
and entry user name and corresponding password as above setting `.env`
`MLFLOW_TRACKING_USERNAME` and `MLFLOW_TRACKING_PASSWORD`

## During running python ML training code


