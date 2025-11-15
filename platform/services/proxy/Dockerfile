FROM nginx:alpine

# Install apache2-utils for htpasswd
RUN apk add --no-cache apache2-utils

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy webserver startup script
COPY webserver.sh /webserver.sh
RUN chmod +x /webserver.sh

# Create directory for htpasswd and certs
RUN mkdir -p /etc/nginx/auth /etc/nginx/certs

# Create placeholder for certificates
RUN mkdir -p /etc/nginx/certs && \
    echo "Place your SSL certificates here:" > /etc/nginx/certs/README.txt && \
    echo "  - server.crt" >> /etc/nginx/certs/README.txt && \
    echo "  - server.key" >> /etc/nginx/certs/README.txt

EXPOSE 80 443

CMD ["/webserver.sh"]
