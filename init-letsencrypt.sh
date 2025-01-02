#!/bin/bash

# init-letsencrypt.sh

# ==========================
# 変数設定
# ==========================
domains=(example.xyz)
email="abc@example.xyz"
staging=0  # 1 にすると Let's Encrypt ステージング環境（テスト用）
           # 0 にすると本番環境
# ==========================

# === クリーンアップ ===
docker compose down
sudo rm -rf certbot          # 既存の証明書等を削除（注意！）
mkdir -p certbot/conf
mkdir -p certbot/www/.well-known/acme-challenge
chmod -R 755 certbot

# テストファイルの作成 (ACME Challenge 確認用)
echo "Hello, Let's Encrypt!" > certbot/www/.well-known/acme-challenge/test.txt

# === default.conf をバックアップ & HTTPS サーバーブロックをコメントアウト ===
cp default.conf default.conf.bak
sed -i '/listen 443/,/}/ s/^/#/' default.conf

echo "### Starting nginx without SSL ..."
docker compose up -d nginx-proxy

echo "### Waiting for nginx to start..."
sleep 10

echo "### Testing ACME challenge access..."
curl -v http://${domains[0]}/.well-known/acme-challenge/test.txt

echo "### Requesting Let's Encrypt certificate ..."
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

# === 証明書取得確認 ===
if [ ! -f "./certbot/conf/live/${domains[0]}/fullchain.pem" ] && [ ! -L "./certbot/conf/live/${domains[0]}/fullchain.pem" ]; then
    echo "### Certificate was not obtained successfully. Exiting."
    exit 1
fi

echo "### Adjusting certificate file permissions..."
sudo chmod 644 ./certbot/conf/live/${domains[0]}/fullchain.pem
sudo chmod 600 ./certbot/conf/live/${domains[0]}/privkey.pem

# === default.conf を元に戻す (HTTPSサーバーブロック有効化) ===
mv default.conf.bak default.conf

echo "### Testing nginx configuration..."
docker compose exec nginx-proxy nginx -t

echo "### Restarting nginx with SSL ..."
docker compose restart nginx-proxy

echo "### Final check..."
curl -v https://${domains[0]}/.well-known/acme-challenge/test.txt