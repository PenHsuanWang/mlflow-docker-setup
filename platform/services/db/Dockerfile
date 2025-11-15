FROM mysql:8.0

# Copy custom MySQL configuration
COPY my.cnf /etc/mysql/conf.d/custom.cnf

# Healthcheck to ensure MySQL is ready
HEALTHCHECK --interval=10s --timeout=5s --retries=5 \
    CMD mysqladmin ping -h 127.0.0.1 --silent || exit 1
