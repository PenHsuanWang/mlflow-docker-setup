## MLflow Docker Setup – Unified Platform
[![CI](https://github.com/PenHsuanWang/mlflow-docker-setup/actions/workflows/tests.yml/badge.svg)](https://github.com/PenHsuanWang/mlflow-docker-setup/actions/workflows/tests.yml)

> **📣 New unified `platform/` stack** – The legacy `backend-storage/` and `tracking-server/` folders are deprecated. Use the instructions below or see [MIGRATION.md](MIGRATION.md) if you still need the old layout.

## 1. Overview

This repository delivers a production-ready MLflow deployment composed of:

- **MLflow Tracking Server** – experiment tracking, registry, REST API
- **MySQL Backend Store** – persistent metadata with health checks
- **Artifact Server (port 5500)** – dedicated artifact storage via MLflow Scenario 5
- **NGINX Reverse Proxy** – Basic Auth, TLS-ready ingress for the UI/API
- **Profile-based Compose files** – simple dev/prod toggles, consistent networking

📖 **Documentation:**
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Complete architecture with network & volume diagrams
- **[QUICK_START_VERIFIED.md](QUICK_START_VERIFIED.md)** - Verified quick start guide
- **[DEPLOYMENT_TEST_REPORT.md](DEPLOYMENT_TEST_REPORT.md)** - Test results & validation
- **[detail_design_document.md](detail_design_document.md)** - Original design decisions

### Architecture & Data Persistence

Full details in **[ARCHITECTURE.md](ARCHITECTURE.md)**. The platform uses Docker named volumes for persistent storage:

**Network Architecture:**
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

**Volume Architecture:**
```
┌─────────────────────────────────────────────────────────────────┐
│                      Docker Named Volumes                        │
│                                                                   │
│  Development Mode (mlflow-dev_*)                                │
│  ┌──────────────────────┬──────────────────────────────────┐    │
│  │ mysql_data           │ /var/lib/mysql                    │    │
│  │ • Database metadata  │ • Experiments, runs, metrics      │    │
│  │ • User accounts      │ • Model registry                  │    │
│  └──────────────────────┴──────────────────────────────────┘    │
│                                                                   │
│  ┌──────────────────────┬──────────────────────────────────┐    │
│  │ artifact_data        │ /app/mlartifacts                  │    │
│  │ • Model artifacts    │ • Training artifacts              │    │
│  │ • Plots & figures    │ • Model files (PKL, H5, etc.)     │    │
│  └──────────────────────┴──────────────────────────────────┘    │
│                                                                   │
│  Production Mode (mlflow-prod_*) - Additional Volume            │
│  ┌──────────────────────┬──────────────────────────────────┐    │
│  │ proxy_auth           │ /etc/nginx/auth                   │    │
│  │ • htpasswd file      │ • Basic auth credentials          │    │
│  │ • Persistent auth    │ • User authentication data        │    │
│  └──────────────────────┴──────────────────────────────────┘    │
│                                                                   │
│  Volume Naming Convention:                                       │
│  • Development: mlflow-dev_<volume_name>                         │
│  • Production:  mlflow-prod_<volume_name>                        │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

**Volume Management:**

| Volume Name | Mount Point | Purpose | Lifecycle |
|-------------|-------------|---------|-----------|
| `mysql_data` | `/var/lib/mysql` | MySQL database files | Persists across restarts |
| `artifact_data` | `/app/mlartifacts` | Model artifacts & files | Persists across restarts |
| `proxy_auth` | `/etc/nginx/auth` | NGINX authentication | Persists across restarts (prod only) |

**Data Persistence Guarantees:**
- **Restart Safe**: Data survives `docker-compose down` (without `-v` flag)
- **Upgrade Safe**: Volumes persist during platform upgrades
- **Disaster Recovery**: Volumes can be backed up using `docker volume` commands
- **Development**: Volumes use prefix `mlflow-dev_*`
- **Production**: Volumes use prefix `mlflow-prod_*`

**Volume Cleanup:**
```bash
# WARNING: These commands DELETE ALL DATA

# Remove development volumes
docker-compose -f docker-compose.core.yml -f docker-compose.dev.override.yml \
  --env-file ../env/dev.env down -v

# Remove production volumes
docker-compose -f docker-compose.core.yml -f docker-compose.proxy.yml \
  --env-file ../env/prod.env --profile proxy down -v

# Manually remove specific volumes
docker volume rm mlflow-dev_mysql_data
docker volume rm mlflow-dev_artifact_data
docker volume rm mlflow-prod_mysql_data
docker volume rm mlflow-prod_artifact_data
docker volume rm mlflow-prod_proxy_auth
```

**Backup & Recovery:**
```bash
# Backup volumes
docker run --rm -v mlflow-prod_mysql_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/mysql_backup.tar.gz -C /data .

docker run --rm -v mlflow-prod_artifact_data:/data -v $(pwd):/backup \
  alpine tar czf /backup/artifact_backup.tar.gz -C /data .

# Restore volumes
docker volume create mlflow-prod_mysql_data
docker run --rm -v mlflow-prod_mysql_data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/mysql_backup.tar.gz -C /data

docker volume create mlflow-prod_artifact_data
docker run --rm -v mlflow-prod_artifact_data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/artifact_backup.tar.gz -C /data
```

**Container Dependencies:**

The platform follows a strict startup order to ensure proper initialization:

```
1. db (mysql)          ← Started first
   ↓ (healthy)
2. artifact (mlflow)   ← Waits for db to be healthy
   ↓ (started)
3. tracking (mlflow)   ← Waits for db healthy + artifact started
   ↓ (started)
4. proxy (nginx)       ← Waits for tracking started (prod only)
```

**Container Details:**

| Container | Image | Internal Port | External Port (Dev) | External Port (Prod) | Role |
|-----------|-------|---------------|---------------------|----------------------|------|
| `mlflow-{env}-db` | `mysql:8.0` | 3306 | 3316 | Not exposed | Metadata storage |
| `mlflow-{env}-artifact` | Custom MLflow | 5500 | 5500 | Not exposed | Artifact server |
| `mlflow-{env}-tracking` | Custom MLflow | 5001 | 5011 | Not exposed | Tracking UI/API |
| `mlflow-{env}-proxy` | `nginx:alpine` | 80/443 | Not used | 7777/7443 | Reverse proxy (prod only) |

*Note: `{env}` is either `dev` or `prod` based on `COMPOSE_PROJECT_NAME`*

**Health Checks:**

All containers implement health checks to ensure reliability:

```yaml
db:
  healthcheck:
    test: ["CMD", "mysqladmin", "ping", "-h", "127.0.0.1", "--silent"]
    interval: 10s
    timeout: 5s
    retries: 5

artifact:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:5500/health"]
    interval: 30s
    timeout: 10s
    retries: 3

tracking:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:5001/health"]
    interval: 30s
    timeout: 10s
    retries: 3
```

**Startup Verification:**

Check all containers are running:
```bash
# View container status
docker ps --filter "name=mlflow"

# Check logs
docker logs mlflow-dev-tracking --tail 50
docker logs mlflow-dev-artifact --tail 50
docker logs mlflow-dev-db --tail 50

# Production
docker logs mlflow-prod-tracking --tail 50
docker logs mlflow-prod-proxy --tail 50
```

## 2. Quick Start

### Option A – Interactive script
```bash
./quick-start.sh
```

### Option B – Manual Docker Compose
```bash
cd platform/compose

# Development (direct access with exposed ports)
docker-compose -f docker-compose.core.yml -f docker-compose.dev.override.yml \
  --env-file ../env/dev.env up -d
# UI → http://localhost:5011
# Artifact Server → http://localhost:5500
# MySQL → localhost:3316

# Production-style (proxy + auth + TLS-ready)
docker-compose -f docker-compose.core.yml -f docker-compose.proxy.yml \
  --env-file ../env/prod.env --profile proxy up -d
# UI → http://localhost:7777  (credentials from env file)
```

To stop everything:
```bash
cd platform/compose
# For development
docker-compose -f docker-compose.core.yml -f docker-compose.dev.override.yml \
  --env-file ../env/dev.env down

# For production
docker-compose -f docker-compose.core.yml -f docker-compose.proxy.yml \
  --env-file ../env/prod.env --profile proxy down
```

## 3. Environment & Secrets

The platform uses environment files to manage credentials and configuration. Three env files are provided:

### Environment Files

| File | Purpose | When to Use |
|------|---------|-------------|
| `platform/env/base.env` | Non-sensitive defaults | Template/reference only |
| `platform/env/dev.env` | Development settings | Local testing and development |
| `platform/env/prod.env` | Production template | Production deployments (customize first!) |

### Key Environment Variables

```bash
# MySQL Database
MYSQL_ROOT_PASSWORD=root_dev_password      # Root user password
MYSQL_PASSWORD=mlflow_dev_password         # MLflow user password
MYSQL_USER=mlflow                          # Database username (default: mlflow)
MYSQL_DATABASE=mlflow                      # Database name

# MLflow Backend Store Connection
MLFLOW_BACKEND_STORE_URI=mysql+pymysql://mlflow:mlflow_dev_password@db:3306/mlflow

# MLflow Tracking Authentication (for NGINX proxy)
MLFLOW_TRACKING_USERNAME=admin             # Web UI username
MLFLOW_TRACKING_PASSWORD=admin123          # Web UI password

# Logging
GUNICORN_LOG_LEVEL=debug                   # Options: debug, info, warning, error

# Network
COMPOSE_PROJECT_NAME=mlflow-dev            # Docker Compose project name
```

### Setup Instructions

**For Development:**
```bash
# Use dev.env as-is, or customize if needed
cd platform/compose
docker-compose -f docker-compose.core.yml -f docker-compose.dev.override.yml \
  --env-file ../env/dev.env up -d
```

**For Production:**
```bash
# 1. Create a local copy (not tracked by git)
cp platform/env/prod.env platform/env/.env.local

# 2. Edit .env.local with strong passwords
nano platform/env/.env.local

# 3. Update these values:
#    MYSQL_ROOT_PASSWORD=<strong-password>
#    MYSQL_PASSWORD=<strong-password>
#    MLFLOW_TRACKING_USERNAME=<your-username>
#    MLFLOW_TRACKING_PASSWORD=<strong-password>

# 4. Launch with your custom config
cd platform/compose
docker-compose -f docker-compose.core.yml -f docker-compose.proxy.yml \
  --env-file ../env/.env.local --profile proxy up -d
```

### Using Credentials

When connecting to MySQL directly, use the password from your env file:

```bash
# For development (password: mlflow_dev_password)
docker exec -it mlflow-dev-db mysql -u mlflow -p
# Enter password: mlflow_dev_password

# For production (password: from your .env.local)
docker exec -it <container-name> mysql -u mlflow -p
# Enter password: <your MYSQL_PASSWORD from .env.local>
```

**Security Best Practices:**
- Never commit `.env.local` or files with real credentials
- Use strong, unique passwords in production
- Rotate credentials periodically
- Consider using Docker secrets for production deployments

## 4. Service Reference

| Service  | Container Port | Default Host Port (dev) | Description |
|----------|----------------|-------------------------|-------------|
| `db`     | 3306           | 3316                    | MySQL backend store supporting MLflow registry |
| `artifact` | 5500        | 5500                    | MLflow artifact server (`--artifacts-only`) |
| `tracking` | 5001        | 5011                    | MLflow tracking UI/API (direct access in dev) |
| `proxy`  | 80 / 443      | 7777 / 7443             | NGINX reverse proxy with Basic Auth + TLS |

- Internal networking: all services join `mlops_net`; only `proxy` attaches to `mlops_public`.
- Health/order: MySQL exposes a healthcheck, and `tracking` waits for both DB and artifact endpoints.

## 5. Access & Testing

### UI access
- **Dev**: `http://localhost:5011`
- **Proxy**: `http://localhost:7777` or `https://localhost:7443`

### API smoke test
```bash
# Experiment list
curl -f http://localhost:5011/api/2.0/mlflow/experiments/search?max_results=5
# Health endpoints
curl -f http://localhost:5500/health
curl -f http://localhost:5011/health
```

### Logs & troubleshooting
```bash
cd platform/compose
docker compose -f docker-compose.core.yml logs -f tracking
docker compose -f docker-compose.core.yml logs -f artifact
docker compose -f docker-compose.core.yml logs -f db
```

### Database shell
```bash
# Connect to MySQL (password from env file)
docker exec -it mlflow-dev-db mysql -u mlflow -p
# Enter password when prompted: mlflow_dev_password (from dev.env)
#                          or: <MYSQL_PASSWORD> (from your .env.local)

# Alternative: View database status
docker exec mlflow-dev-db mysql -u mlflow -pmlflow_dev_password -e "SHOW DATABASES;"
```

## 6. ML Client Usage

```python
import mlflow, os

# Choose the correct endpoint
mlflow.set_tracking_uri("http://localhost:5011")  # direct dev access
# mlflow.set_tracking_uri("http://localhost:7777")  # via proxy / production

os.environ["MLFLOW_TRACKING_USERNAME"] = "<user>"
os.environ["MLFLOW_TRACKING_PASSWORD"] = "<pass>"

mlflow.set_experiment("demo")
with mlflow.start_run():
    mlflow.log_param("alpha", 0.5)
    mlflow.log_metric("rmse", 0.87)
    mlflow.log_text("hello world", "notes.txt")
```

Model serving workflow:
```bash
export MLFLOW_TRACKING_URI=http://localhost:5011
mlflow models serve --no-conda -m "models:/power-forecasting-model/Production" -p 5002
curl http://localhost:5002/invocations -X POST -H 'Content-Type: application/json' \
  -d '[{"feature1":1.0,"feature2":2.0}]'
```

## 7. Networking & Security Highlights

- Internal traffic stays on `mlops_net`; only the proxy exposes ports.
- `nginx` forwards `X-Forwarded-*` headers and supports TLS certificates mounted under `platform/services/proxy/certs`.
- `webserver.sh` keeps `.htpasswd` persistent, so Basic Auth credentials survive restarts.
- Dev overrides can expose MySQL (`3316:3306`) or artifact port for diagnostics; production mode keeps them internal.

## 8. Documentation Map

- [detail_design_document.md](detail_design_document.md) – rationale for the refactor
- [ARCHITECTURE_ANALYSIS.md](ARCHITECTURE_ANALYSIS.md) – in-depth current-state review
- [MIGRATION.md](MIGRATION.md) – steps to move off legacy stacks
- [TESTING_SUMMARY.md](TESTING_SUMMARY.md) / [TEST_REPORT.md](TEST_REPORT.md) – CI expectations

## 9. Contributing & Support

- Run `validate-platform.sh` and `test-platform.sh` before opening PRs.
- File issues with logs (`docker compose logs`) and environment details.
- License: MIT.

---
All operational guidance now lives in this root README; `platform/README.md` simply points here to prevent drift.

