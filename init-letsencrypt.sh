#!/bin/bash

# root権限チェック
if [ "$(id -u)" != "0" ]; then
    echo "このスクリプトはroot権限で実行する必要があります"
    echo "sudo ./init-letsencrypt.sh を実行してください"
    exit 1
fi

# ==========================
# 変数設定
# ==========================
domains=(abc.com)
email="admin@abc.com"
staging=0  # 1 = テストモード、0 = 本番モード
# ==========================

echo "セットアップを開始します..."

# クリーンアップ
echo "1. 環境をクリーンアップしています..."
docker compose down
rm -rf certbot
mkdir -p certbot/conf
mkdir -p certbot/www/.well-known/acme-challenge
chmod -R 755 certbot

# テストファイル作成
echo "Hello, Let's Encrypt!" > certbot/www/.well-known/acme-challenge/test.txt
chmod -R 755 certbot/www

# Nginxの設定準備
echo "2. Nginx設定を準備しています..."
# HTTPSブロックを一時的に無効化した設定を作成
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

# ドメイン名を置換
sed -i "s/DOMAIN_NAME/${domains[0]}/g" default.conf

echo "3. Nginxを起動しています..."
docker compose up -d nginx-proxy
sleep 10

# ACMEチャレンジのテスト
echo "4. ACMEチャレンジのアクセステスト..."
curl -v http://${domains[0]}/.well-known/acme-challenge/test.txt
if [ $? -ne 0 ]; then
    echo "警告: ACMEチャレンジのテストに失敗しました"
    echo "Nginxのログを確認します..."
    docker compose logs nginx-proxy
    echo "5秒後に続行します..."
    sleep 5
fi

echo "5. Let's Encrypt証明書を取得しています..."
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

# 証明書の確認
if [ ! -f "./certbot/conf/live/${domains[0]}/fullchain.pem" ]; then
    echo "エラー: 証明書の取得に失敗しました。"
    echo "Nginxのログを確認:"
    docker compose logs nginx-proxy
    exit 1
fi

echo "6. 証明書のパーミッションを設定しています..."
chmod -R 755 certbot/conf
find certbot/conf -type d -exec chmod 755 {} \;
find certbot/conf -type f -exec chmod 644 {} \;
chmod 600 certbot/conf/live/${domains[0]}/privkey.pem

echo "7. HTTPS設定を有効化しています..."
# 完全な設定を作成
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

# ドメイン名を置換
sed -i "s/DOMAIN_NAME/${domains[0]}/g" default.conf

echo "8. Nginxを再起動しています..."
docker compose down
docker compose up -d
sleep 5

echo "セットアップが完了しました！"
echo ""
echo "重要な情報:"
echo "現在のモード: $([ $staging -eq 1 ] && echo 'テストモード' || echo '本番モード')"
echo "設定したドメイン: ${domains[0]}"
echo ""
echo "次のステップ:"
echo "1. https://${domains[0]} にアクセスしてHTTPSが機能していることを確認してください"
echo ""
echo "エラーが発生した場合は以下のコマンドでログを確認できます:"
echo "docker compose logs nginx-proxy"