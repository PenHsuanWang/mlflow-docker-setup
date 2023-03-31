#!/bin/bash -x

# Add user to htpasswd file
htpasswd -b -c /etc/nginx/.htpasswd ${MLFLOW_TRACKING_USERNAME} ${MLFLOW_TRACKING_PASSWORD}

# Start nginx
nginx -g "daemon off;"
