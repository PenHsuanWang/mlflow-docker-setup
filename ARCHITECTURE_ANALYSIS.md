# MLflow Docker Setup - Comprehensive Architecture Analysis

**Analysis Date:** 2025-11-15  
**Analyst:** GitHub Copilot CLI  
**Purpose:** Complete understanding of current architecture before implementing refactoring

---

## Executive Summary

This project implements an MLflow tracking infrastructure using Docker Compose. It currently consists of **two separate stacks**:
1. **backend-storage**: Core infrastructure (MySQL + Artifact Server + Tracking Server)
2. **tracking-server**: NGINX reverse proxy layer for secure UI access

The architecture review document (`current_atchitrecute_introduction.md`) has identified several critical issues that need addressing, primarily around network configuration, port conflicts, and security hardening.

---

## Current Architecture Deep Dive

### 1. Backend Storage Stack (`/backend-storage`)

#### Components:
- **MySQL Database (db)**
  - Image: `mysql` (no version pinning)
  - Host port: `3316:3306`
  - Network: `shared_network` (bridge, created by this stack)
  - Persistent storage: `~/container_volume_persist/mysql-data-persist`
  - Config: Custom `my.cnf` mounted

- **MLflow Artifact Server (mlflow-artifact-server)**
  - Image: Built from local Dockerfile (Python 3.8 + MLflow 2.2.2)
  - Host port: `5500:5500`
  - Network: `shared_network`
  - Purpose: Handles artifact storage via `--artifacts-only` flag
  - Persistent storage: `~/container_volume_persist/artifact-data-persist`
  - Command: `mlflow server --port 5500 --serve-artifacts --artifacts-only`

- **MLflow Tracking Server (mlflow)**
  - Image: Built from local Dockerfile (Python 3.8 + MLflow 2.2.2)
  - Host port: `5011:5001`
  - Network: `shared_network`
  - Backend store URI: `mysql+pymysql://${USER}:${PASS}@db:3306/mlflowruns`
  - Artifact root: `http://mlflow-artifact-server:5500/api/2.0/mlflow-artifacts/artifacts/experiments`

#### Environment Variables (.env):
```
MYSQL_ROOT_PASSWORD=root
MYSQL_USER=mlflow_pwang
MYSQL_PASSWORD=mlflow_pwang
MLFLOW_BACKEND_DB_USERNAME=root
MLFLOW_BACKEND_DB_PASSWORD=root
MLFLOW_BACKEND_URL=db
MLFLOW_BACKEND_DB=mlflowruns
MLFLOW_ARTIFACT_URL=mlflow-artifact-server
```

### 2. Tracking Server Stack (`/tracking-server`)

#### Components:
- **MLflow Tracking Server (mlflow)**
  - Same name as backend-storage service ⚠️ **CONFLICT**
  - Image: Built from local Dockerfile (Python 3.7 + MLflow - no version pinning)
  - Host port: `5011:5001` ⚠️ **PORT CONFLICT with backend-storage**
  - Network: `shared_network` (expects external network created by backend-storage)
  - Backend store URI: `mysql+pymysql://${USER}:${PASS}@db:3316/mlflowruns` ⚠️ **Uses host port 3316**
  - Artifact root: `http://mlflow-artifact-server:5500/...`

- **NGINX Reverse Proxy (nginx)**
  - Image: Built from nginx base + apache2-utils (for htpasswd)
  - Host port: `7777:80`
  - Network: `shared_network`
  - Config: Custom nginx.conf with upstream `mlflowserver -> mlflow:5001`
  - Authentication: HTTP Basic Auth via htpasswd
  - Startup script: `webserver.sh` creates `.htpasswd` and starts nginx

#### Environment Variables (.env):
```
MYSQL_ROOT_PASSWORD=root
MYSQL_USER=mlflow_pwang
MYSQL_PASSWORD=mlflow_pwang
MLFLOW_TRACKING_USERNAME=<username>
MLFLOW_TRACKING_PASSWORD=<password>
```

### 3. Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Docker Host                               │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │              shared_network (bridge)                        │  │
│  │                                                              │  │
│  │  ┌─────────┐    ┌──────────────────┐    ┌──────────────┐  │  │
│  │  │   db    │◄───│ mlflow-artifact  │◄───│   mlflow     │  │  │
│  │  │ :3306   │    │     :5500        │    │   :5001      │  │  │
│  │  └────▲────┘    └────────▲─────────┘    └──────▲───────┘  │  │
│  │       │                  │                      │           │  │
│  │       │                  │                      │           │  │
│  │       │                  │         ┌────────────▼────────┐ │  │
│  │       │                  │         │      nginx          │ │  │
│  │       │                  │         │      :80            │ │  │
│  │       │                  │         └─────────────────────┘ │  │
│  └───────┼──────────────────┼──────────────────┼──────────────┘  │
│          │                  │                  │                 │
│     Host:3316          Host:5500         Host:7777              │
│                                          Host:5011               │
└─────────────────────────────────────────────────────────────────┘
```

---

## Identified Issues (from Architecture Review)

### Critical Issues:

1. **Port Conflicts**
   - Both stacks define `mlflow` service exposing `5011:5001`
   - Starting both stacks simultaneously causes Docker port binding failure

2. **DNS Name Ambiguity**
   - Both stacks use service name `mlflow`
   - On shared network, DNS round-robins between both containers
   - Unpredictable routing behavior

3. **Incorrect Port References**
   - `tracking-server/docker-compose.yaml` references MySQL at `db:3316`
   - **Wrong**: Inside containers, should use container port `3306`
   - Host port `3316` only relevant for host-to-container connections

4. **Version Inconsistencies**
   - `backend-storage`: Python 3.8 + MLflow 2.2.2
   - `tracking-server`: Python 3.7 + MLflow (unpinned)
   - Risk of incompatibility and inconsistent behavior

### Security Issues:

5. **No TLS/HTTPS Support**
   - NGINX only configured for HTTP on port 80
   - All traffic (including credentials) transmitted in cleartext
   - No X-Forwarded-* headers set for proper proxying

6. **Fragile Authentication**
   - `webserver.sh` recreates `.htpasswd` on every restart using `-c` flag
   - Overwrites existing file, preventing multi-user setups
   - Credentials stored in `.env` files (should use secrets)

7. **Host Path Dependencies**
   - Uses `~/container_volume_persist/` for persistence
   - Tilde expansion not portable across environments
   - Not compatible with Docker Swarm or Kubernetes

### Operational Issues:

8. **No Health Checks**
   - MySQL lacks healthcheck definition
   - MLflow services use `depends_on: condition: service_started`
   - Services may start before MySQL is ready to accept connections

9. **Missing Wait Scripts**
   - No explicit wait-for-db logic in MLflow startup
   - Race conditions possible during stack initialization

10. **Network Mode Confusion**
    - `backend-storage` creates `shared_network`
    - `tracking-server` expects it as `external: true`
    - Requires specific startup order (backend first, then tracking)

---

## Current Workflows

### Workflow 1: ML Training Client
1. Python code sets `MLFLOW_TRACKING_URI=http://localhost:5011`
2. Connects directly to tracking server (bypassing NGINX)
3. Logs parameters/metrics → MySQL backend
4. Saves artifacts → Artifact server via tracking proxy

### Workflow 2: UI Access (with NGINX)
1. User navigates to `http://localhost:7777`
2. NGINX prompts for Basic Auth credentials
3. After auth, NGINX proxies to `mlflow:5001`
4. UI rendered, artifact links point to artifact server

### Workflow 3: Model Serving
1. Set `MLFLOW_TRACKING_URI=http://localhost:5011`
2. Use `mlflow models serve -m models:/<model-name>/<stage>`
3. Local REST endpoint serves predictions
4. Can be dockerized with `mlflow models build-docker`

---

## Strengths of Current Architecture

1. **Separation of Concerns**: Artifact server separate from tracking server
2. **Scenario 5 Compliance**: Follows MLflow official proxied artifact pattern
3. **Persistence**: Data/artifacts survive container restarts
4. **Basic Security**: NGINX provides authentication layer for UI
5. **Documented Setup**: READMEs explain initialization steps
6. **CI/CD Integration**: GitHub Actions workflow tests backend-storage stack

---

## Proposed Refactoring (from detail_design_document.md)

The design document proposes:

### Folder Structure:
```
platform/
├── compose/
│   ├── docker-compose.core.yml       # MySQL + Artifact + Tracking
│   ├── docker-compose.proxy.yml      # NGINX overlay
│   └── docker-compose.dev.override.yml
├── env/
│   ├── base.env
│   ├── dev.env
│   └── prod.env
├── services/
│   ├── db/
│   ├── artifact/
│   ├── tracking/
│   └── proxy/
└── volumes/
```

### Key Improvements:
1. **Unified Stack**: Single compose hierarchy instead of two separate stacks
2. **Profile-Based Deployment**: Use `--profile proxy` to optionally enable NGINX
3. **Network Segregation**: `mlops_net` (internal) + `mlops_public` (ingress)
4. **Unique Service Names**: Avoid `mlflow` name collision
5. **Health Checks**: MySQL healthcheck + wait-for scripts
6. **TLS Readiness**: Certificate mount points + HTTPS redirect config
7. **Secrets Management**: Move credentials to `.env.local` (gitignored)
8. **Named Volumes**: Replace `~/` paths with Docker-managed volumes

---

## Dependencies and Prerequisites

### Current Requirements:
- Docker Engine
- Docker Compose v2
- Python 3.7-3.8 (for client code)
- MySQL client (for manual DB setup)

### Stack Startup Order:
1. Start `backend-storage` stack first (creates shared_network)
2. Manually create MySQL user/database via `docker exec`
3. Start `tracking-server` stack (attaches to existing network)

### External Services:
- None (fully self-contained for local development)
- Future: Could integrate with S3, HDFS, external MySQL

---

## Testing Strategy

### Current Testing:
- GitHub Actions workflow: `.github/workflows/tests.yml`
- Tests backend-storage stack startup
- No automated testing for tracking-server stack
- No integration tests between stacks

### Gaps:
- No end-to-end workflow testing
- No validation of MLflow client connectivity
- No artifact upload/download verification
- No NGINX auth testing

---

## Migration Considerations

### Breaking Changes in Proposed Refactor:
1. Directory structure completely reorganized
2. Service names will change (impact on existing scripts)
3. Network names will change (impact on external integrations)
4. Port mappings may change (impact on firewall rules)
5. Volume paths will change (requires data migration)

### Migration Path:
1. Backup existing MySQL data and artifacts
2. Document current `.env` configurations
3. Build new platform structure alongside old
4. Test new stack in isolation
5. Migrate data to new volumes
6. Update client configurations
7. Deprecate old stacks

---

## Recommendations (Pre-Implementation)

### Phase 1: Fix Critical Issues (Low Risk)
1. ✅ Add MySQL healthcheck
2. ✅ Fix `db:3316` → `db:3306` in tracking-server
3. ✅ Add wait-for script in MLflow startup
4. ✅ Fix `webserver.sh` to preserve existing `.htpasswd`
5. ✅ Add X-Forwarded-* headers to nginx.conf
6. ✅ Pin Python and MLflow versions consistently

### Phase 2: Security Hardening (Medium Risk)
1. ✅ Add TLS certificate support in NGINX
2. ✅ Move credentials to Docker secrets
3. ✅ Replace `~/` paths with named volumes
4. ✅ Add HTTPS redirect logic

### Phase 3: Architecture Refactor (High Risk)
1. ✅ Implement unified platform structure
2. ✅ Consolidate compose files with profiles
3. ✅ Rename services to avoid conflicts
4. ✅ Implement network segregation
5. ✅ Migrate existing data

---

## Conclusion

**Current State**: The architecture is functional but has several production-readiness gaps. The split-stack approach creates operational complexity and potential conflicts.

**Design Document Assessment**: The proposed refactoring in `detail_design_document.md` addresses all identified issues systematically and provides a clear migration path.

**Next Steps**: 
1. ✅ Validate this analysis with stakeholders
2. ⏳ Decide on implementation approach (phased vs. big-bang)
3. ⏳ Begin Phase 1 fixes as low-risk quick wins
4. ⏳ Plan data migration strategy for Phase 3

**Risk Level**: Medium - existing deployments need careful migration planning

---

## Appendix: Key File Locations

### Configuration Files:
- `backend-storage/docker-compose.yaml` - Core stack definition
- `backend-storage/.env` - Backend environment variables
- `backend-storage/Dockerfile` - MLflow base image (Python 3.8)
- `backend-storage/my.cnf` - MySQL configuration

- `tracking-server/docker-compose.yaml` - Proxy stack definition
- `tracking-server/.env` - Tracking environment variables
- `tracking-server/Dockerfile` - MLflow base image (Python 3.7)
- `tracking-server/build-nginx/nginx.conf` - NGINX configuration
- `tracking-server/webserver.sh` - NGINX startup script

### Documentation:
- `README.md` - Main project documentation
- `current_atchitrecute_introduction.md` - Architecture review findings
- `detail_design_document.md` - Refactoring proposal
- `backend-storage/README.md` - Backend stack setup
- `tracking-server/README.md` - Tracking stack setup

### CI/CD:
- `.github/workflows/tests.yml` - GitHub Actions testing workflow

---

**End of Analysis**
