-- Create MLflow database and user
CREATE DATABASE IF NOT EXISTS mlflow CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Note: User creation is handled by environment variables in docker-compose
-- This script can be extended for additional database initialization
