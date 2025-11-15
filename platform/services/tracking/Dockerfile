FROM python:3.8-slim

WORKDIR /app

# Install MLflow and dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install netcat for wait-for script
RUN apt-get update && apt-get install -y netcat-traditional && rm -rf /var/lib/apt/lists/*

# Copy wait-for script
COPY wait-for.sh /app/wait-for.sh
RUN chmod +x /app/wait-for.sh

EXPOSE 5001

# Tracking server will be started via docker-compose command
