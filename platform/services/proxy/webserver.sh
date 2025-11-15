#!/bin/sh
set -e

# Validate required environment variables
if [ -z "$MLFLOW_TRACKING_USERNAME" ] || [ -z "$MLFLOW_TRACKING_PASSWORD" ]; then
    echo "Error: MLFLOW_TRACKING_USERNAME and MLFLOW_TRACKING_PASSWORD must be set"
    exit 1
fi

# Create htpasswd file only if it doesn't exist
HTPASSWD_FILE="/etc/nginx/auth/.htpasswd"

if [ ! -f "$HTPASSWD_FILE" ]; then
    echo "Creating new htpasswd file..."
    htpasswd -b -c "$HTPASSWD_FILE" "$MLFLOW_TRACKING_USERNAME" "$MLFLOW_TRACKING_PASSWORD"
else
    echo "Htpasswd file exists. Updating user credentials..."
    # Remove existing user if present, then add
    htpasswd -D "$HTPASSWD_FILE" "$MLFLOW_TRACKING_USERNAME" 2>/dev/null || true
    htpasswd -b "$HTPASSWD_FILE" "$MLFLOW_TRACKING_USERNAME" "$MLFLOW_TRACKING_PASSWORD"
fi

echo "Starting NGINX..."
exec nginx -g "daemon off;"
