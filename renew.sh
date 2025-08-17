#!/usr/bin/env bash
set -euo pipefail

# Renew Let's Encrypt certificates using webroot and reload nginx container.
# Intended to be invoked manually or via cron/systemd timer.

DOMAINS_DIR="./certbot/conf/live"
WEBROOT="$(pwd)/certbot/www"
LECONF="$(pwd)/certbot/conf"
NGINX_CONTAINER="proxy-nginx"

if ! docker ps >/dev/null 2>&1; then
  echo "Docker is not available. Please ensure Docker is installed and running." >&2
  exit 1
fi

if [ ! -d "$WEBROOT" ] || [ ! -d "$LECONF" ]; then
  echo "Expected directories not found. Run ./init-letsencrypt.sh first." >&2
  exit 1
fi

echo "Running certbot renew..."
docker run --rm \
  -v "$WEBROOT:/var/www/certbot" \
  -v "$LECONF:/etc/letsencrypt" \
  certbot/certbot renew \
  --webroot -w /var/www/certbot \
  --deploy-hook "nginx -s reload" || true

# The deploy-hook above runs in the certbot container, not nginx.
# To reliably reload nginx, run it from host using docker exec:
if docker ps --format '{{.Names}}' | grep -qx "$NGINX_CONTAINER"; then
  echo "Reloading nginx inside container: $NGINX_CONTAINER"
  docker exec "$NGINX_CONTAINER" nginx -t && docker exec "$NGINX_CONTAINER" nginx -s reload
else
  echo "Warning: Nginx container '$NGINX_CONTAINER' not running; skipping reload." >&2
fi

echo "Renewal cycle completed."

