FROM python:3.8-slim

WORKDIR /app

# Install MLflow and dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create artifacts directory
RUN mkdir -p /app/mlartifacts

EXPOSE 5500

# Artifact server will be started via docker-compose command
