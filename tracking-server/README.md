## Connect to mlflow server backend

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


