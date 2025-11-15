# TLS Certificate Configuration

To enable HTTPS for the MLflow proxy:

1. Place your SSL/TLS certificates in this directory:
   - `server.crt` - Certificate file
   - `server.key` - Private key file

2. Uncomment the HTTPS server block in `nginx.conf`

3. Update `docker-compose.proxy.yml` to expose port 7443

4. Restart the proxy service:
   ```bash
   docker compose -f docker-compose.core.yml -f docker-compose.proxy.yml --profile proxy restart proxy
   ```

## Generating Self-Signed Certificates (Development Only)

For development/testing, you can generate self-signed certificates:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout server.key \
  -out server.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
```

**Warning**: Self-signed certificates should NOT be used in production!

## Production Certificates

For production, obtain certificates from:
- Let's Encrypt (free, automated)
- Commercial Certificate Authority (CA)
- Your organization's internal CA

## Certificate Permissions

Ensure proper permissions:
```bash
chmod 644 server.crt
chmod 600 server.key
```
