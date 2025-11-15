## Architecture verification & deployment notes (code review)

I inspected the Docker Compose setups for the `backend-storage` stack and the `tracking-server` stack, and verified how each behaves when started separately or together.

### What happens when you start `backend-storage/docker-compose.yaml`

- `db` (MySQL) starts on container port 3306 and is published to the host at `3316` (mapping `3316:3306`). The Compose file references environment variables loaded from `backend-storage/.env`.
- `mlflow-artifact-server` starts on port `5500` (internal) and is published to the host on `5500:5500`. It uses `./mlartifacts` inside the container for artifacts, with a host path available via the volumes setting.
- `mlflow` starts on port `5001` internally and is published to the host on `5011:5001`. It configures the MLflow backend store using env vars (for example `MYSQL+pymysql://${MLFLOW_BACKEND_DB_USERNAME}:${MLFLOW_BACKEND_DB_PASSWORD}@${MLFLOW_BACKEND_URL}:3306/${MLFLOW_BACKEND_DB}`) and sets artifact root to `http://${MLFLOW_ARTIFACT_URL}:5500/...`.

Conclusion: Starting `backend-storage` will bring up MySQL, the artifact-server, and a working MLflow Tracking Server UI that is reachable on the host port `5011`.

### What happens when you start `tracking-server/docker-compose.yaml`

- `tracking-server` expects an existing `shared_network` (the stack uses an external network), and it connects to other services (MySQL and artifact) by DNS name or alias.
- It also defines an `mlflow` service and an `nginx` service. The `nginx` reverse-proxy listens on host port `7777` and forwards requests to the `mlflow` service behind the proxy.
- `nginx` uses `webserver.sh` to populate a basic auth password file (`htpasswd`) and then starts NGINX. `nginx.conf` defines an upstream `mlflowserver` that points to `mlflow:5001`.

Conclusion: Starting `tracking-server` will bring up a second MLflow server (if not already present) and NGINX which proxies the UI; the UI becomes available via `http://localhost:7777`.

### Cross-stack behavior & conflicts

- If you start both stacks without changes, you will likely start two independent `mlflow` services that attempt to publish the same host port mapping (`5011:5001`), which causes port conflict on the host port 5011. Consider exposing different host ports or run only one in production.
- Both stacks use the same Docker network name (`shared_network`) and the same service name `mlflow`. When both services are on the same network, the DNS name `mlflow` resolves to all containers with that hostname and can produce ambiguous resolution; depending on launch order it may round-robin requests between both containers (not desirable). Use unique service names or add network aliases to disambiguate.
- The `tracking-server` `docker-compose.yaml` references MySQL using host port `3316` (`${MLFLOW_BACKEND_URL}:3316`). Inside a container you should call MySQL on the container port `3306` and use the service name `db`. Use `db:3306` rather than `db:3316`. The current setup works only if you rely on host port mapping and non standard DNS routes (not recommended).

### Security & network notes

- `tracking-server/nginx.conf` provides a basic proxy and basic authentication; however the connection to `mlflow` is not encrypted (HTTP) and the proxy runs on `80`. For strong security you should add TLS termination at NGINX and prefer `https://` for both UI and client access.
- `webserver.sh` uses `htpasswd -b -c` which overwrites `.htpasswd` every container start. A safer approach is to only create it when missing and to avoid storing credentials in repo or `.env` file.

### Recommended fixes and improvements

1. Internal ports vs host ports: use container port numbers for inter-service connections. Change back-end URIs to `db:3306` instead of `db:3316`.
2. Avoid duplicate `mlflow` service names: rename one of them (e.g., `mlflow` -> `mlflow-backend`) or use network aliases to avoid DNS name ambiguity.
3. Avoid host `~` expanded volumes; prefer repo-relative or named Docker volumes for portability.
4. Add a DB `healthcheck` and use a `wait-for` script in `mlflow` startup instead of `depends_on: condition: service_started`.
5. Add TLS/HTTPS on the `nginx` reverse-proxy for secure UI and client access; forward `X-Forwarded-*` headers in the `nginx.conf`.
6. Use a non-root DB user configured consistently in `.env` and `docker-compose` and ensure the user and DB exist in the DB environment creation.
7. Use `mlflow` version pinning in `requirements.txt` or in Dockerfile and align versions for both stacks.

### Example small fixes (copy/paste)

1) Use a container port for the backend-store of tracking server:

--backend-store-uri "mysql+pymysql://mlflow:mlflow@db:3306/mlflowruns"

2) Use artifact-service name (instead of 127.0.0.1):

--default-artifact-root "http://mlflow-artifact-server:5500/api/2.0/mlflow-artifacts/artifacts"

3) Add `healthcheck` for MySQL:

```
db:
	image: mysql:8.0
	healthcheck:
		test: ["CMD","mysqladmin","ping","-h","127.0.0.1"]
		interval: 10s
		timeout: 5s
		retries: 5
```

4) Fix `webserver.sh` to preserve `.htpasswd`:

```
if [ ! -f /etc/nginx/.htpasswd ]; then
	htpasswd -b -c /etc/nginx/.htpasswd "$MLFLOW_TRACKING_USERNAME" "$MLFLOW_TRACKING_PASSWORD"
else
	htpasswd -b /etc/nginx/.htpasswd "$MLFLOW_TRACKING_USERNAME" "$MLFLOW_TRACKING_PASSWORD"
fi
```

### Final result

When `backend-storage` is started alone, it will bring up MySQL, artifact server, and the MLflow tracking server accessible on `localhost:5011`. When `tracking-server` is started alone, it will bring up its own `mlflow` and `nginx` proxy accessible at `localhost:7777`. If both stacks are started together, address port collisions, services DNS ambiguity, and internal port usage as per the suggestions above.

If you want me to apply these modifications (compose changes, `webserver.sh` guard, or `nginx.conf` header improvements) I can prepare a PR with a minimal, tested patch.

