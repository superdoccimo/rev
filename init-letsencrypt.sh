#!/bin/bash

# Check for root privileges
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root."
    echo "Please run it with sudo: sudo ./init-letsencrypt.sh"
    exit 1
fi

# ==========================
# Variable settings
# ==========================
domains=(abc.com)
email="admin@abc.com"
staging=0  # 1 = Staging mode, 0 = Production mode
# ==========================

echo "Starting setup..."

# Cleanup
echo "1. Cleaning up the environment..."
docker compose down
rm -rf certbot
mkdir -p certbot/conf
mkdir -p certbot/www/.well-known/acme-challenge
chmod -R 755 certbot

# Create test file
echo "Hello, Let's Encrypt!" > certbot/www/.well-known/acme-challenge/test.txt
chmod -R 755 certbot/www

# Preparing Nginx configuration
echo "2. Preparing Nginx configuration..."
# Create a configuration with the HTTPS block temporarily disabled
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

# Replace domain name
sed -i "s/DOMAIN_NAME/${domains[0]}/g" default.conf

echo "3. Starting Nginx..."
docker compose up -d nginx-proxy
sleep 10

# Test ACME challenge
echo "4. Testing access to ACME challenge..."
curl -v http://${domains[0]}/.well-known/acme-challenge/test.txt
if [ $? -ne 0 ]; then
    echo "Warning: ACME challenge test failed."
    echo "Checking Nginx logs..."
    docker compose logs nginx-proxy
    echo "Continuing in 5 seconds..."
    sleep 5
fi

echo "5. Obtaining Let's Encrypt certificate..."
docker run -it --rm \
    -v "$PWD/certbot/www:/var/www/certbot" \
    -v "$PWD/certbot/conf:/etc/letsencrypt" \
    certbot/certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$email" \
    -d "${domains[0]}" \
    --agree-tos \
    --force-renewal \
    --non-interactive \
    $( [ $staging -eq 1 ] && echo "--staging" ) \
    -v

# Verify certificate
if [ ! -f "./certbot/conf/live/${domains[0]}/fullchain.pem" ]; then
    echo "Error: Failed to obtain certificate."
    echo "Check Nginx logs:"
    docker compose logs nginx-proxy
    exit 1
fi

echo "6. Setting certificate permissions..."
chmod -R 755 certbot/conf
find certbot/conf -type d -exec chmod 755 {} \;
find certbot/conf -type f -exec chmod 644 {} \;
chmod 600 certbot/conf/live/${domains[0]}/privkey.pem

echo "7. Enabling HTTPS configuration..."
# Create full configuration
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
    listen 443 ssl;
    server_name DOMAIN_NAME;

    ssl_certificate     /etc/letsencrypt/live/DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/DOMAIN_NAME/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;

    location / {
        proxy_pass http://10.0.0.37:8080;
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

# Replace domain name
sed -i "s/DOMAIN_NAME/${domains[0]}/g" default.conf

echo "8. Restarting Nginx..."
docker compose down
docker compose up -d
sleep 5

echo "Setup is complete!"
echo ""
echo "Important information:"
echo "Current mode: $([ $staging -eq 1 ] && echo 'Staging mode' || echo 'Production mode')"
echo "Configured domain: ${domains[0]}"
echo ""
echo "Next steps:"
echo "1. Access https://${domains[0]} to ensure HTTPS is functioning correctly."
echo ""
echo "If an error occurs, you can check the logs with the following command:"
echo "docker compose logs nginx-proxy"
