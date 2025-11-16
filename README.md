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

Architecture summary (details in [detail_design_document.md](detail_design_document.md)):

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

## 2. Quick Start

### Option A – Interactive script
```bash
./quick-start.sh
```

### Option B – Manual Docker Compose
```bash
cd platform/compose

# Development (direct access, no proxy)
docker compose -f docker-compose.core.yml \
  --env-file ../env/dev.env up -d
# UI → http://localhost:5011

# Production-style (proxy + auth + TLS-ready)
docker compose -f docker-compose.core.yml -f docker-compose.proxy.yml \
  --env-file ../env/prod.env --profile proxy up -d
# UI → http://localhost:7777  (credentials from env file)

# Development with host volumes and extra logging
docker compose -f docker-compose.core.yml -f docker-compose.dev.override.yml \
  --env-file ../env/dev.env up -d
```

To stop everything:
```bash
cd platform/compose
docker compose -f docker-compose.core.yml down
docker compose -f docker-compose.core.yml -f docker-compose.proxy.yml --profile proxy down
```

## 3. Environment & Secrets

1. Copy `platform/env/base.env` to `platform/env/.env.local` and customize (never commit `.env.local`).
2. Required values:
   - `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`, `MLFLOW_DB_PASSWORD`
   - `MLFLOW_TRACKING_USERNAME`, `MLFLOW_TRACKING_PASSWORD`
   - Optional TLS paths for proxy when HTTPS is enabled
3. Load different env files via `--env-file ../env/dev.env` or `../env/prod.env`.

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
docker exec -it mlflow-dev-db mysql -u mlflow -p
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

