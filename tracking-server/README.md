## Connect to mlflow server backend

before starting docker compose
create env file
```
cat <<EOT >> .env
MLFLOW_BACKEND_DB_USERNAME=<db_username>
MLFLOW_BACKEND_DB_PASSWORD=<db_password>
MLFLOW_BACKEND_DB=<db_name>
MLFLOW_BACKEND_URL=ec2-44-213-176-187.compute-1.amazonaws.com
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



