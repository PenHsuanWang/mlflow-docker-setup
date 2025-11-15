# MLflow Platform - Unified Docker Setup

This directory contains the refactored MLflow platform with a unified, production-ready architecture.

## Architecture Overview

```
platform/
├── compose/                   # Docker Compose configurations
│   ├── docker-compose.core.yml          # Core services (MySQL, Artifact, Tracking)
│   ├── docker-compose.proxy.yml         # NGINX reverse proxy (optional)
│   └── docker-compose.dev.override.yml  # Development overrides
├── env/                       # Environment configurations
│   ├── base.env              # Base configuration (defaults)
│   ├── dev.env               # Development settings
│   └── prod.env              # Production template
├── services/                  # Service definitions
│   ├── db/                   # MySQL database
│   ├── artifact/             # MLflow artifact server
│   ├── tracking/             # MLflow tracking server
│   └── proxy/                # NGINX reverse proxy
└── volumes/                   # Local development volumes (gitignored)
```

## Quick Start

### Development Mode (Direct Access)

Start core services without proxy:

```bash
cd platform/compose
docker compose -f docker-compose.core.yml --env-file ../env/dev.env up -d
```

Access MLflow UI directly at: `http://localhost:5011`

### Production Mode (With NGINX Proxy)

Start all services including secure proxy:

```bash
cd platform/compose
docker compose -f docker-compose.core.yml -f docker-compose.proxy.yml \
  --env-file ../env/prod.env --profile proxy up -d
```

Access MLflow UI via proxy at: `http://localhost:7777`  
Login with credentials from `env/prod.env`

### Development Mode with Local Volumes

For easier debugging with host-mounted volumes:

```bash
cd platform/compose
docker compose -f docker-compose.core.yml -f docker-compose.dev.override.yml \
  --env-file ../env/dev.env up -d
```

## Service Ports

| Service   | Internal Port | Host Port (dev) | Purpose                    |
|-----------|---------------|-----------------|----------------------------|
| MySQL     | 3306          | 3316            | Database backend           |
| Artifact  | 5500          | 5500            | Artifact storage           |
| Tracking  | 5001          | 5011            | MLflow tracking server     |
| NGINX     | 80/443        | 7777/7443       | Reverse proxy with auth    |

## Environment Configuration

### Development

Copy and customize the development environment:

```bash
cp platform/env/dev.env platform/env/.env.local
# Edit .env.local with your settings
```

### Production

**Important**: Never commit production credentials!

```bash
cp platform/env/prod.env platform/env/.env.local
# Edit .env.local with strong passwords
```

Required variables:
- `MYSQL_ROOT_PASSWORD` - MySQL root password
- `MYSQL_PASSWORD` - MLflow database user password
- `MLFLOW_TRACKING_USERNAME` - NGINX auth username
- `MLFLOW_TRACKING_PASSWORD` - NGINX auth password

## Common Operations

### View Logs

```bash
# All services
docker compose -f docker-compose.core.yml logs -f

# Specific service
docker compose -f docker-compose.core.yml logs -f tracking
```

### Stop Services

```bash
docker compose -f docker-compose.core.yml down

# With proxy
docker compose -f docker-compose.core.yml -f docker-compose.proxy.yml --profile proxy down
```

### Remove Volumes (Clean Start)

```bash
docker compose -f docker-compose.core.yml down -v
```

### Database Shell Access

```bash
docker exec -it mlflow-dev-db mysql -u mlflow -p
```

## ML Client Configuration

### Python

```python
import mlflow

# Direct access (dev mode)
mlflow.set_tracking_uri("http://localhost:5011")

# Via proxy (production)
mlflow.set_tracking_uri("http://localhost:7777")
os.environ["MLFLOW_TRACKING_USERNAME"] = "your_username"
os.environ["MLFLOW_TRACKING_PASSWORD"] = "your_password"

# Log experiments
with mlflow.start_run():
    mlflow.log_param("alpha", 0.5)
    mlflow.log_metric("rmse", 0.87)
```

## Networking

### Internal Network (`mlops_net`)
- All services communicate on this bridge network
- Service DNS names: `db`, `artifact`, `tracking`, `proxy`
- No external access (except via mapped ports)

### Public Network (`mlops_public`)
- Only NGINX proxy connects here
- Exposes ports 7777 (HTTP) and 7443 (HTTPS)

## Security Features

✅ MySQL healthchecks prevent premature startup  
✅ Wait-for scripts ensure dependency readiness  
✅ NGINX Basic Auth protects UI access  
✅ X-Forwarded-* headers for proper proxying  
✅ htpasswd preserved across restarts  
✅ TLS/HTTPS ready (certificate configuration required)  
✅ Secrets externalized to environment files  

## Upgrading from Legacy Setup

See `MIGRATION.md` for step-by-step upgrade instructions from the old `backend-storage` and `tracking-server` stacks.

## Troubleshooting

### Services won't start
```bash
# Check health status
docker compose -f docker-compose.core.yml ps

# View detailed logs
docker compose -f docker-compose.core.yml logs
```

### Database connection errors
```bash
# Verify MySQL is healthy
docker exec mlflow-dev-db mysqladmin ping -h localhost

# Check database exists
docker exec mlflow-dev-db mysql -u mlflow -pmlflow_dev_password -e "SHOW DATABASES;"
```

### Proxy authentication issues
```bash
# Check htpasswd file
docker exec mlflow-dev-proxy cat /etc/nginx/auth/.htpasswd

# Restart proxy with fresh auth
docker compose -f docker-compose.proxy.yml --profile proxy restart proxy
```

## Support

For issues, see:
- `ARCHITECTURE_ANALYSIS.md` - Architecture documentation
- `detail_design_document.md` - Design decisions
- GitHub Issues - Report bugs

## License

Same as parent project.
