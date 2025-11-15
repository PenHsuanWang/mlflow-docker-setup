## MLflow Docker Setup - Production-Ready Platform
[![Docker Compose Tests](https://github.com/PenHsuanWang/mlflow-docker-setup/actions/workflows/tests.yml/badge.svg)](https://github.com/PenHsuanWang/mlflow-docker-setup/actions/workflows/tests.yml)

> **📣 New Unified Platform Architecture!**  
> The project has been refactored into a unified `platform/` structure with improved security, networking, and deployment options. See [MIGRATION.md](MIGRATION.md) for upgrade instructions.

## Overview

A complete, production-ready MLflow infrastructure using Docker Compose. This setup provides:

✅ **MLflow Tracking Server** - Experiment tracking and model versioning  
✅ **MySQL Backend** - Persistent metadata storage with health checks  
✅ **Artifact Server** - Dedicated artifact storage service  
✅ **NGINX Reverse Proxy** - Secure UI access with authentication  
✅ **TLS/HTTPS Ready** - Certificate configuration support  
✅ **Development & Production Modes** - Flexible deployment options  

## Quick Start

### Option 1: Interactive Quick Start (Recommended)

```bash
./quick-start.sh
```

### Option 2: Manual Start

**Development (Direct Access):**
```bash
cd platform/compose
docker compose -f docker-compose.core.yml --env-file ../env/dev.env up -d
```
Access at: `http://localhost:5011`

**Production (With Proxy & Auth):**
```bash
cd platform/compose
docker compose -f docker-compose.core.yml -f docker-compose.proxy.yml \
  --env-file ../env/dev.env --profile proxy up -d
```
Access at: `http://localhost:7777` (user: admin, pass: admin123)

## Documentation

- **[Platform README](platform/README.md)** - Complete operational guide
- **[Migration Guide](MIGRATION.md)** - Upgrade from legacy setup
- **[Architecture Analysis](ARCHITECTURE_ANALYSIS.md)** - Technical deep dive
- **[Design Document](detail_design_document.md)** - Refactoring rationale

## What We Provide

* **MLflow Tracking Server** - Model versioning control and experiment tracing
* **MySQL Backend Store** - Persistent storage for experiment metadata
* **Artifact Server** - Scalable storage for models, data, and large objects
* **NGINX Reverse Proxy** - Secure access with Basic Auth and TLS support
* **Health Checks** - Automatic dependency management and readiness detection
* **Multiple Deployment Modes** - Development, staging, and production configurations



## Architecture

### Official MLflow Design Pattern

This implementation follows [MLflow Scenario 5: Tracking Server with Proxied Artifact Storage](https://www.mlflow.org/docs/latest/tracking.html#scenario-5-mlflow-tracking-server-enabled-with-proxied-artifact-storage).

```
┌─────────────────────────────────────────────────────────────────┐
│                    MLflow Platform Services                      │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              mlops_net (internal bridge)                  │   │
│  │                                                            │   │
│  │  ┌─────────┐    ┌──────────┐    ┌───────────┐           │   │
│  │  │   db    │◄───│ artifact │◄───│ tracking  │           │   │
│  │  │ :3306   │    │  :5500   │    │  :5001    │           │   │
│  │  └─────────┘    └──────────┘    └─────▲─────┘           │   │
│  │                                        │                  │   │
│  │                              ┌─────────┴────────┐        │   │
│  │                              │  proxy (nginx)   │        │   │
│  │                              │  :80 / :443      │        │   │
│  │                              └──────────────────┘        │   │
│  └──────────────────────────────────────┼───────────────────┘   │
│                                          │                       │
│                    mlops_public ─────────┘                       │
│                                                                   │
└───────────────────────────────────┬─────────────────────────────┘
                                    │
                         Host: 7777 (HTTP) / 7443 (HTTPS)
                              5011 (Direct - Dev only)
```

### Key Features

1. **Network Segregation**: Internal `mlops_net` for service communication, `mlops_public` for ingress
2. **Service Naming**: Unique names (`db`, `artifact`, `tracking`, `proxy`) avoid DNS conflicts
3. **Health Checks**: MySQL healthcheck + wait-for scripts ensure proper startup order
4. **Security**: NGINX Basic Auth, TLS-ready, proper X-Forwarded headers
5. **Flexibility**: Profile-based deployment (with/without proxy)


## ML Client Usage

### Python Example

```python
import mlflow
import os

# Configure tracking URI
mlflow.set_tracking_uri("http://localhost:5011")  # Direct (dev)
# or
mlflow.set_tracking_uri("http://localhost:7777")  # Via proxy (prod)

# For proxy auth (production)
os.environ["MLFLOW_TRACKING_USERNAME"] = "admin"
os.environ["MLFLOW_TRACKING_PASSWORD"] = "admin123"

# Create experiment
mlflow.set_experiment("my-experiment")

# Log experiment
with mlflow.start_run():
    # Log parameters
    mlflow.log_param("alpha", 0.5)
    mlflow.log_param("l1_ratio", 0.1)
    
    # Log metrics
    mlflow.log_metric("rmse", 0.87)
    mlflow.log_metric("r2", 0.92)
    
    # Log model
    mlflow.sklearn.log_model(model, "model")
```

### Register and Deploy Models

```bash
# Set tracking server
export MLFLOW_TRACKING_URI=http://localhost:5011

# Serve model locally
mlflow models serve --no-conda -m "models:/my-model/Production" -p 5002

# Build Docker image for model serving
mlflow models build-docker -m "models:/my-model/Production" -n "my-model-serving"

# Run model serving container
docker run -p 5002:8080 my-model-serving
```

### Make Predictions

```bash
# Test prediction endpoint
curl http://localhost:5002/invocations -X POST -H 'Content-Type: application/json' \
  -d '[{"feature1": 1.0, "feature2": 2.0}]'
```

## Common Operations

### View Logs
```bash
cd platform/compose
docker compose -f docker-compose.core.yml logs -f tracking
```

### Database Access
```bash
docker exec -it mlflow-dev-db mysql -u mlflow -p
```

### Stop Services
```bash
cd platform/compose
docker compose -f docker-compose.core.yml down
```

## Troubleshooting

See [platform/README.md](platform/README.md) for detailed troubleshooting guide.

## Legacy Setup

The old `backend-storage` and `tracking-server` directories are deprecated. See [MIGRATION.md](MIGRATION.md) to upgrade to the new platform architecture.

## Contributing

Issues and pull requests are welcome! Please see the architecture documentation before making major changes.

## License

This project is open source and available under the MIT License.

