#!/usr/bin/env bash
set -euo pipefail

# ==========================
# Variable settings
# ==========================
domains=(abc.com)               # You can list multiple domains here (e.g., abc.com www.abc.com)
email="admin@abc.com"           # Email for Let's Encrypt registration and notices
staging=0                       # 1 = Staging mode, 0 = Production mode
upstream="http://10.0.0.37:8080" # Upstream application URL (http://host:port)
# ==========================

echo "Starting setup..."

echo "1. Preparing directories and environment..."
mkdir -p certbot/conf
mkdir -p certbot/www/.well-known/acme-challenge
chmod -R 755 certbot

# Create test file
echo "Hello, Let's Encrypt!" > certbot/www/.well-known/acme-challenge/test.txt
chmod -R 755 certbot/www

# Preparing Nginx configuration (HTTP only for ACME)
echo "2. Preparing Nginx HTTP configuration for ACME..."
cat > default.conf << 'EOL'
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    server_name DOMAIN_NAME;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri =404;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}
EOL

# Replace domain name (first domain for HTTP server_name)
sed -i "s/DOMAIN_NAME/${domains[0]}/g" default.conf

echo "3. Starting Nginx (HTTP only)..."
docker compose up -d nginx-proxy
sleep 10

# Test ACME challenge
echo "4. Testing access to ACME challenge..."
if ! curl --silent --fail "http://${domains[0]}/.well-known/acme-challenge/test.txt" >/dev/null; then
    echo "Warning: ACME challenge test failed (HTTP 200 not returned)." >&2
    echo "Checking Nginx logs..." >&2
    docker compose logs nginx-proxy || true
    echo "Continuing in 5 seconds... (ensure DNS A record points to this host and port 80 is open)" >&2
    sleep 5
fi

echo "5. Obtaining Let's Encrypt certificate..."

# Build -d args for all domains
domain_args=()
for d in "${domains[@]}"; do
  domain_args+=("-d" "$d")
done

live_dir="./certbot/conf/live/${domains[0]}"
if [ -f "$live_dir/fullchain.pem" ] && [ -f "$live_dir/privkey.pem" ]; then
  echo "Existing certificate found for ${domains[0]}. Skipping obtain step."
else
  docker run --rm \
      -v "$PWD/certbot/www:/var/www/certbot" \
      -v "$PWD/certbot/conf:/etc/letsencrypt" \
      certbot/certbot certonly \
      --webroot \
      --webroot-path=/var/www/certbot \
      --email "$email" \
      "${domain_args[@]}" \
      --agree-tos \
      --non-interactive \
      --key-type ecdsa --elliptic-curve secp384r1 \
      $( [ "$staging" -eq 1 ] && echo "--staging" )
fi

# Verify certificate
if [ ! -f "./certbot/conf/live/${domains[0]}/fullchain.pem" ]; then
    echo "Error: Failed to obtain certificate."
    echo "Check Nginx logs:"
    docker compose logs nginx-proxy
    exit 1
fi

echo "6. Setting certificate permissions..."
chmod -R go-w certbot/conf || true
find certbot/conf -type d -exec chmod 755 {} \; || true
find certbot/conf -type f -exec chmod 644 {} \; || true
chmod 600 certbot/conf/live/${domains[0]}/privkey.pem || true

echo "7. Writing full HTTPS configuration..."
cat > default.conf << 'EOL'
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80;
    server_name DOMAIN_NAME;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri =404;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name DOMAIN_NAME;

    ssl_certificate     /etc/letsencrypt/live/DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/DOMAIN_NAME/privkey.pem;

    # TLS hardening
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:50m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
    ssl_ecdh_curve X25519:secp384r1;

    # OCSP stapling (requires trusted chain file)
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/live/DOMAIN_NAME/chain.pem;
    resolver 1.1.1.1 1.0.0.1 valid=300s;
    resolver_timeout 5s;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options SAMEORIGIN always;
    add_header Referrer-Policy no-referrer-when-downgrade always;

    location / {
        proxy_pass UPSTREAM_TARGET;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_buffering off;
    }
}
EOL

# Replace placeholders
sed -i "s/DOMAIN_NAME/${domains[0]}/g" default.conf
sed -i "s|UPSTREAM_TARGET|${upstream}|g" default.conf

echo "8. Reloading Nginx with HTTPS..."
if docker compose exec -T nginx-proxy nginx -t; then
  docker compose exec -T nginx-proxy nginx -s reload
else
  echo "Nginx config test failed, doing a safe restart..." >&2
  docker compose down
  docker compose up -d
fi
sleep 3

echo "Setup is complete!"
echo ""
echo "Important information:"
echo "Current mode: $([ "$staging" -eq 1 ] && echo 'Staging mode' || echo 'Production mode')"
echo "Configured domains: ${domains[*]}"
echo ""
echo "Next steps:"
echo "1. Access https://${domains[0]} to ensure HTTPS is functioning correctly."
echo "2. Configure automatic renewal via ./renew.sh or cron (see README)."
echo ""
echo "If an error occurs, you can check the logs with the following command:"
echo "docker compose logs nginx-proxy"
