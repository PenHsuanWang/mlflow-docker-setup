# Migration Guide: Legacy to Platform Architecture

This guide helps you migrate from the legacy `backend-storage` + `tracking-server` setup to the new unified `platform/` architecture.

## Pre-Migration Checklist

- [ ] Backup existing MySQL data
- [ ] Backup existing artifacts
- [ ] Document current `.env` configurations
- [ ] Stop all running containers
- [ ] Test new platform in parallel (recommended)

## Migration Strategy

We recommend a **parallel migration** approach:

1. Keep legacy stacks running
2. Start new platform stack with fresh data
3. Test thoroughly
4. Migrate data
5. Switch traffic
6. Deprecate legacy

## Step 1: Backup Existing Data

### Backup MySQL Database

```bash
# Export MLflow database
docker exec backend-storage-db-1 mysqldump -u root -proot mlflowruns > mlflow_backup.sql

# Or backup entire data directory
cp -r ~/container_volume_persist/mysql-data-persist ~/mlflow-mysql-backup
```

### Backup Artifacts

```bash
# Copy artifacts directory
cp -r ~/container_volume_persist/artifact-data-persist ~/mlflow-artifacts-backup
```

### Save Current Configuration

```bash
# Backup environment files
cp backend-storage/.env backend-storage/.env.backup
cp tracking-server/.env tracking-server/.env.backup
```

## Step 2: Stop Legacy Stacks

```bash
# Stop backend-storage
cd backend-storage
docker compose down

# Stop tracking-server
cd ../tracking-server
docker compose down

# Optionally remove old network
docker network rm shared_network
```

## Step 3: Configure New Platform

### Create Environment File

```bash
cd platform/env

# For development
cp dev.env .env.local

# For production
cp prod.env .env.local
```

### Update Credentials

Edit `.env.local` with your credentials from the legacy `.env` files:

```bash
# From backend-storage/.env
MYSQL_ROOT_PASSWORD=<your_value>
MYSQL_PASSWORD=<your_value>

# From tracking-server/.env
MLFLOW_TRACKING_USERNAME=<your_value>
MLFLOW_TRACKING_PASSWORD=<your_value>
```

## Step 4: Start New Platform

### Option A: Fresh Start (Recommended for Testing)

```bash
cd platform/compose

# Start core services
docker compose -f docker-compose.core.yml --env-file ../env/.env.local up -d

# Verify health
docker compose -f docker-compose.core.yml ps
```

### Option B: With Proxy

```bash
cd platform/compose

# Start all services
docker compose -f docker-compose.core.yml -f docker-compose.proxy.yml \
  --env-file ../env/.env.local --profile proxy up -d
```

## Step 5: Migrate Data

### Option A: Restore from SQL Dump

```bash
# Copy backup into container
docker cp mlflow_backup.sql mlflow-dev-db:/tmp/

# Restore database
docker exec -i mlflow-dev-db mysql -u root -p<password> mlflow < /tmp/mlflow_backup.sql
```

### Option B: Copy Data Volumes

If you want to reuse the exact same data:

```bash
# Stop new platform
cd platform/compose
docker compose -f docker-compose.core.yml down

# Copy MySQL data
docker volume create mlflow-dev_mysql_data
docker run --rm -v ~/mlflow-mysql-backup:/source -v mlflow-dev_mysql_data:/dest busybox sh -c "cp -a /source/. /dest/"

# Copy artifacts
docker volume create mlflow-dev_artifact_data
docker run --rm -v ~/mlflow-artifacts-backup:/source -v mlflow-dev_artifact_data:/dest busybox sh -c "cp -a /source/. /dest/"

# Restart platform
docker compose -f docker-compose.core.yml --env-file ../env/.env.local up -d
```

## Step 6: Verify Migration

### Check Database Connection

```bash
# Access database
docker exec -it mlflow-dev-db mysql -u mlflow -p

# Verify data
USE mlflow;
SHOW TABLES;
SELECT COUNT(*) FROM experiments;
SELECT COUNT(*) FROM runs;
```

### Test MLflow UI

- **Direct access**: http://localhost:5011
- **Via proxy**: http://localhost:7777 (with authentication)

### Test ML Client

```python
import mlflow

mlflow.set_tracking_uri("http://localhost:5011")

# List experiments
experiments = mlflow.search_experiments()
print(f"Found {len(experiments)} experiments")

# List runs
runs = mlflow.search_runs()
print(f"Found {len(runs)} runs")
```

## Step 7: Update Client Code

### Old Configuration

```python
# Legacy setup
mlflow.set_tracking_uri("http://localhost:5011")  # Direct to backend-storage
# or
mlflow.set_tracking_uri("http://localhost:7777")  # Via tracking-server proxy
```

### New Configuration

```python
# Development (direct access)
mlflow.set_tracking_uri("http://localhost:5011")

# Production (via proxy with auth)
import os
mlflow.set_tracking_uri("http://localhost:7777")
os.environ["MLFLOW_TRACKING_USERNAME"] = "your_username"
os.environ["MLFLOW_TRACKING_PASSWORD"] = "your_password"
```

**No changes needed!** The platform maintains backward-compatible port mappings.

## Step 8: Cleanup Legacy Stacks

Once you've verified the new platform works correctly:

```bash
# Remove old containers and images
cd backend-storage
docker compose down -v --rmi all

cd ../tracking-server
docker compose down -v --rmi all

# Optionally archive old configs
mkdir -p ../archived-legacy
mv ../backend-storage ../archived-legacy/
mv ../tracking-server ../archived-legacy/
```

## Troubleshooting Migration

### Port Conflicts

If you get port binding errors:

```bash
# Check what's using the ports
sudo netstat -tulpn | grep -E '3316|5500|5011|7777'

# Or use lsof
sudo lsof -i :5011
```

### Database Connection Issues

```bash
# Check MySQL logs
docker logs mlflow-dev-db

# Verify credentials
docker exec mlflow-dev-db mysql -u mlflow -p<password> -e "SELECT 1"
```

### Missing Data After Migration

```bash
# Check volume contents
docker run --rm -v mlflow-dev_mysql_data:/data busybox ls -la /data

# Check permissions
docker exec mlflow-dev-db ls -la /var/lib/mysql
```

## Rollback Procedure

If you need to rollback to the legacy setup:

```bash
# Stop new platform
cd platform/compose
docker compose -f docker-compose.core.yml down

# Restore legacy stacks
cd ../../backend-storage
docker compose up -d

cd ../tracking-server
docker compose up -d
```

Your backup data remains in `~/mlflow-mysql-backup` and `~/mlflow-artifacts-backup`.

## Key Differences: Legacy vs Platform

| Feature | Legacy | Platform |
|---------|--------|----------|
| Service naming | `mlflow` (conflict) | `tracking` (unique) |
| MySQL port | `db:3316` (wrong) | `db:3306` (correct) |
| Network | `shared_network` | `mlops_net` + `mlops_public` |
| Health checks | None | MySQL + wait scripts |
| Volumes | Host paths (`~/`) | Named Docker volumes |
| Python version | 3.7 vs 3.8 | 3.8 (consistent) |
| MLflow version | Unpinned vs 2.2.2 | 2.2.2 (pinned) |
| Proxy auth | Overwrites htpasswd | Preserves htpasswd |
| TLS support | No | Ready (config needed) |

## Post-Migration Best Practices

1. **Update CI/CD pipelines** to use new compose files
2. **Update documentation** with new URLs and credentials
3. **Monitor logs** for the first few days
4. **Set up backups** for Docker volumes
5. **Configure TLS** for production (see `platform/services/proxy/certs/README.md`)
6. **Implement secrets management** (e.g., Docker Secrets, Vault)

## Getting Help

If you encounter issues:

1. Check `platform/README.md` for operational guidance
2. Review `ARCHITECTURE_ANALYSIS.md` for architecture details
3. Search existing GitHub issues
4. Open a new issue with migration logs

---

**Migration Status Checklist:**

- [ ] Data backed up
- [ ] New platform tested
- [ ] Data migrated successfully
- [ ] Client code updated
- [ ] Production deployment verified
- [ ] Legacy stacks removed
- [ ] Team documentation updated
