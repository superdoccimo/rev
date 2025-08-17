#!/usr/bin/env bash
set -euo pipefail

echo "[preflight] loading .env (if present)"
[ -f .env ] && set -a && . ./.env && set +a

UPSTREAM="${UPSTREAM:-http://127.0.0.1:8080}"
DOMAINS="${DOMAINS:-}"
EMAIL="${EMAIL:-}"
LE_CONF="${LE_CONF:-./certbot/conf}"
LE_WEBROOT="${LE_WEBROOT:-./certbot/www}"
NGINX_CONTAINER="${NGINX_CONTAINER:-proxy-nginx}"

fail() { echo "ERROR: $*" >&2; exit 1; }

command -v docker >/dev/null || fail "docker not found"
docker compose version >/dev/null || fail "docker compose not available"

[ -n "$DOMAINS" ] || echo "WARN: DOMAINS is empty (set in .env for diag/renew convenience)" >&2
[ -n "$EMAIL" ]   || echo "WARN: EMAIL is empty (set in .env for reference)" >&2

echo "[preflight] checking ports 80/443 availability on host"
if command -v ss >/dev/null; then
  if ss -lnt | awk '{print $4}' | grep -Eq '[:.]80$'; then
    echo "WARN: TCP/80 appears in use on host"
  fi
  if ss -lnt | awk '{print $4}' | grep -Eq '[:.]443$'; then
    echo "WARN: TCP/443 appears in use on host"
  fi
else
  echo "INFO: 'ss' not found; skipping port check"
fi

echo "[preflight] checking DNS A/AAAA for first domain"
FIRST_DOMAIN="$(echo "$DOMAINS" | awk '{print $1}')"
if [ -n "$FIRST_DOMAIN" ]; then
  if command -v dig >/dev/null; then
    echo "A records:";   dig +short "$FIRST_DOMAIN" A   || true
    echo "AAAA records:"; dig +short "$FIRST_DOMAIN" AAAA || true
  else
    echo "INFO: 'dig' not found, skipping DNS check"
  fi
else
  echo "INFO: DOMAINS not provided; skipping DNS check"
fi

echo "[preflight] ensuring directories exist"
mkdir -p "$LE_CONF" "$LE_WEBROOT/.well-known/acme-challenge"

echo "[preflight] nginx config syntax (if container up)"
if docker ps --format '{{.Names}}' | grep -qx "$NGINX_CONTAINER"; then
  docker exec "$NGINX_CONTAINER" nginx -t || fail "nginx -t failed inside container"
else
  echo "INFO: nginx container '$NGINX_CONTAINER' not running yet; syntax check skipped"
fi

echo "[preflight] upstream reachability (best-effort)"
UPSTREAM_HOST="$(echo "$UPSTREAM" | sed -E 's#https?://([^/:]+).*#\1#')"
if ping -c1 -W1 "$UPSTREAM_HOST" >/dev/null 2>&1; then
  echo "OK: upstream host reachable: $UPSTREAM_HOST"
else
  echo "WARN: upstream host not reachable: $UPSTREAM_HOST"
fi

echo "[preflight] done"

