## Refactor Design for MLflow Docker Stack

### 1. Objectives & Constraints
- Keep the existing components (MySQL backend store, MLflow artifact server on 5500, MLflow tracking server, NGINX proxy for UI access) but reorganize them into a single, coherent folder/compose hierarchy.
- Resolve the issues enumerated in `current_atchitrecute_introduction.md` (port conflicts, duplicate service names, ambiguous networking, missing TLS readiness, fragile auth provisioning).
- Support three primary use cases: (1) ML model training code connecting to the tracking server for logging and registry operations, (2) model-serving systems invoking registered models via MLflow, (3) human users accessing the MLflow UI securely through the proxy.
- Improve network segregation and future-proof the stack for TLS certificates and secrets management without implementing the code yet.

### 2. Proposed Folder & File Layout
```
mlflow-docker-setup/
	docs/
		current_atchitrecute_introduction.md
		detail_design_document.md
	platform/
		compose/
			docker-compose.core.yml        # MySQL + artifact + tracking
			docker-compose.proxy.yml       # NGINX overlay (optional profile)
			docker-compose.dev.override.yml# Local developer overrides
		env/
			base.env
			dev.env
			prod.env
		services/
			db/
				Dockerfile (optional) / my.cnf / init.sql
			artifact/
				Dockerfile / requirements.txt / entrypoint.sh
			tracking/
				Dockerfile / requirements.txt / gunicorn.conf.py / wait-for-it.sh
			proxy/
				Dockerfile / nginx.conf / webserver.sh / certs/
		volumes/
			mysql/
			mlartifacts/
	README.md (updated quickstart pointing to platform/compose)
```
- `platform/compose` becomes the single source of truth. Each compose file references Dockerfiles under `platform/services/...`.
- `.env` files live under `platform/env` and are loaded via `--env-file` or `env_file` entries. Sensitive values move to `.env.local` (ignored) or Docker secrets.

### 3. Docker Compose Strategy
1. **docker-compose.core.yml**
	 - Services: `db`, `mlflow-artifact`, `mlflow-tracking`.
	 - Defines a dedicated network `mlops_net` (bridge) plus an optional `mlops_public` for exposed ports.
	 - Uses healthchecks and `depends_on` (service_healthy) or an explicit wait script.
	 - Publishes host ports only where necessary (e.g., MySQL optional). Primary host access goes through NGINX proxy.

2. **docker-compose.proxy.yml**
	 - Extends the core stack and adds the `nginx-proxy` service.
	 - Mounts certificates (self-signed or Let's Encrypt) and `.htpasswd` from `platform/services/proxy`.
	 - Exposes port `7777` (HTTP) and optional `7443/9443` (HTTPS) to host.

3. **Profiles**
	 - Compose profiles let users start subsets: `docker compose --profile proxy up -d` brings up everything including NGINX; without the profile only backend components run for local testing.

4. **Overrides**
	 - `docker-compose.dev.override.yml` maps repo volumes (`./volumes/mysql`) for persistence and enables extra logging.
	 - Production deployments can copy `prod.env` and use named volumes defined in the core compose file to avoid host path dependencies.

### 4. Networking & Security Enhancements
- **Networks**
	- `mlops_net`: internal bridge network for db/artifact/tracking/proxy containers. Only `nginx-proxy` attaches to `mlops_public` for ingress.
	- Strict service names/aliases, e.g., `db`, `artifact`, `tracking`, `proxy`. Avoid duplicate names.
	- `mlflow-tracking` references MySQL via `db:3306` and artifact via `mlflow-artifact:5500` (no host ports in URIs).

- **Ports**
	- Expose MySQL only when required: optional host port mapping in dev override (`3316:3306`).
	- Artifact server remains on container port `5500`; host exposure is optional. Tracking server only exposes internally (no direct host binding) when proxy is enabled.

- **TLS Readiness**
	- `nginx-proxy` includes volume mounts for `/etc/nginx/certs` and a `certs/README` to document placing PEM files. Compose overlay can be extended to run Certbot or use Traefik.
	- Proxy configuration forwards `X-Forwarded-*` headers and enforces HTTPS redirect when certs exist.

- **Secrets**
	- Move DB/root/user passwords into `platform/env/base.env` (non-sensitive defaults) and `.env.local` (ignored). Document how to load secrets via `docker compose --env-file platform/env/prod.env`.
	- Provide `platform/services/db/init/01-create-mlflow-user.sql` for explicit user provisioning instead of relying on environment comments.

### 5. Service Designs
#### 5.1 MySQL (`db`)
- Image: `mysql:8.0` with `my.cnf` copied from `platform/services/db`.
- Healthcheck ensures service is reachable before `mlflow-tracking` starts.
- Data persistence: named volume `mysql_data` or bind mount (per profile).
- Optional `init.sql` for user/database creation executed via `/docker-entrypoint-initdb.d`.

#### 5.2 MLflow Artifact Server (`mlflow-artifact`)
- Dockerfile pinning MLflow version (shared `requirements.txt`).
- Serves artifacts via `mlflow server --artifacts-only --port 5500 --artifacts-destination /app/mlartifacts`.
- Mounts named volume `mlartifacts_data` to `/app/mlartifacts`.
- No host port binding in core compose; proxy or dev override handles external access if required.

#### 5.3 MLflow Tracking Server (`mlflow-tracking`)
- Dockerfile reuses same requirements as artifact service for consistency.
- `command` example:
	```
	/app/scripts/wait-for db:3306 -- ./scripts/wait-for mlflow-artifact:5500 -- \
	mlflow server \
		--host 0.0.0.0 \
		--port 5001 \
		--backend-store-uri mysql+pymysql://mlflow:${MLFLOW_DB_PASSWORD}@db:3306/mlflow \
		--default-artifact-root http://mlflow-artifact:5500/api/2.0/mlflow-artifacts/artifacts \
		--gunicorn-opts "--log-level info"
	```
- Exposes container port 5001 only to the internal network. Host access goes through NGINX in standard deployments.
- Includes readiness probe script to emit health status for future orchestration.

#### 5.4 NGINX Proxy (`nginx-proxy`)
- Dockerfile builds from `nginx:alpine`, copies `nginx.conf`, `webserver.sh`, `htpasswd.template`, optional `certs/`.
- Supports HTTP Basic Auth + optional OIDC future integration (documented in README).
- Listens on 7777 (HTTP) and 7443 (HTTPS). Default behavior: redirect HTTP → HTTPS when certs provided; otherwise keep HTTP for local dev.
- `webserver.sh` generates `.htpasswd` only when missing and validates env vars (`MLFLOW_TRACKING_USERNAME/PASSWORD`).

### 6. Interaction Flows
1. **ML Model Training Clients**
	 - Clients set `MLFLOW_TRACKING_URI=https://mlops.local` (proxy address) and `MLFLOW_TRACKING_USERNAME/PASSWORD`.
	 - Traffic terminates at `nginx-proxy`, is authenticated, forwarded over `mlops_net` to `mlflow-tracking`, which writes metadata to MySQL and stores artifacts via HTTP calls to `mlflow-artifact`.

2. **Model Registration**
	 - Training code calls `mlflow.register_model`. Since both Tracking and Artifact endpoints reside within the network, artifact URIs resolve internally; external systems reach them via the proxy when needed.

3. **Model Serving / CI Systems**
	 - Serving stack (outside this repo) uses MLflow REST API via proxy on 7777/7443 to discover or download models. Provide service account credentials via secrets.
	 - Optional: expose `mlflow-tracking` API via internal network peering (e.g., when serving runs in same Docker host) using `mlops_net` connect or `docker compose network connect`.

4. **Human UI Access**
	 - Users visit `https://mlops.local` (nginx). Basic auth enforced; future implementation can add TLS client cert or OIDC.
	 - Proxy forwards `X-Forwarded-*` headers so MLflow generates correct artifact links using HTTPS scheme.

### 7. Migration Plan
1. Create `platform/` structure and move existing service files into `platform/services/...` without code changes.
2. Author `docker-compose.core.yml` referencing the relocated Dockerfiles and configs. Test startup using new network/volume names.
3. Add `docker-compose.proxy.yml` overlay and verify TLS-off mode (HTTP only) first; then document certificate placement.
4. Update `.env` handling (create `platform/env/base.env`, move secrets, update `.gitignore`).
5. Update docs/README to reference new commands:
	 ```bash
	 cd platform
	 docker compose --env-file env/dev.env -f compose/docker-compose.core.yml -f compose/docker-compose.proxy.yml --profile proxy up -d
	 ```
6. Remove legacy `backend-storage` and `tracking-server` folders after verifying parity.

### 8. Open Questions / Follow-ups
- Decide whether artifact server should remain accessible directly (port 5500) or exclusively via MLflow proxy endpoints.
- Evaluate replacing Basic Auth with OIDC or mTLS for production hardening.
- Consider splitting MySQL into managed service and leaving container only for development scenarios.
- Determine automation for TLS certificate issuance (Certbot within container, Traefik, or external load balancer).

### 9. Docker Compose Startup Network Architecture
- **Network creation order**: `docker-compose.core.yml` declares `mlops_net` (internal) and `mlops_public` (ingress). When `docker compose up` runs, Docker creates the networks before starting containers. If `docker-compose.proxy.yml` is omitted, only `mlops_net` exists.
- **Service attachments**:
	- `db`, `mlflow-artifact`, and `mlflow-tracking` join `mlops_net` only. They expose container ports (3306, 5500, 5001) to the bridge but remain unreachable from the host unless a profile override adds host bindings.
	- `nginx-proxy` joins both networks. On `mlops_net` it talks to upstream services via DNS (`db`, `mlflow-artifact`, `mlflow-tracking`). On `mlops_public` it binds host ports `7777`/`7443` for ingress.
- **Traffic path at startup**: As soon as `db` reports healthy, the wait script allows `mlflow-tracking` to start. Tracking connects to MySQL over the internal bridge (`db:3306`) and registers the artifact base URL pointing at `mlflow-artifact:5500`. When the proxy profile is enabled, external clients hit `nginx-proxy` which forwards to `mlflow-tracking`. All artifact downloads requested via MLflow UI/API are proxied back across `mlops_net` to the artifact server.
- **Isolation guarantees**: Because application containers never attach to `mlops_public`, only the proxy can expose services to the host. Developers who need direct DB access enable the dev override to publish `3316:3306` temporarily; that override is not used in production. This separation satisfies the requirements for training clients, serving systems, and UI users while minimizing accidental cross-talk between stacks.

This design keeps all existing components while consolidating them under a single, maintainable folder structure and improving network/security posture for both automation clients and UI users.
