#!/bin/bash

# root権限チェック
if [ "$(id -u)" != "0" ]; then
    echo "このスクリプトはroot権限で実行する必要があります"
    echo "sudo ./enable-https.sh を実行してください"
    exit 1
fi

# 変数設定
domain="stock.minokamo.xyz"

# 証明書の存在確認
if [ ! -e "./certbot/conf/live/${domain}/fullchain.pem" ]; then
    echo "SSL certificates not found. Please run init-letsencrypt.sh first."
    exit 1
fi

# default.conf のバックアップを作成
cp default.conf default.conf.bak

# HTTPSサーバーブロックのコメントを解除
# コメントアウトの行を探して削除
sed -i '# --- HTTPSサーバーブロックは一時的にコメントアウト ---/d' default.conf
# #で始まる行からコメントを解除（空白を含む行も対象）
sed -i 's/^# *//' default.conf

# Nginx設定のテスト
echo "Testing nginx configuration..."
if docker compose exec nginx-proxy nginx -t; then
    # 設定が正しい場合、Nginxを再起動
    echo "Configuration test successful. Restarting nginx..."
    docker compose restart nginx-proxy
    echo "HTTPS has been enabled successfully!"
    echo "Try accessing https://${domain}"
else
    # 設定に問題がある場合、バックアップから復元
    echo "Configuration test failed. Rolling back changes..."
    mv default.conf.bak default.conf
    exit 1
fi

# バックアップファイルを削除
rm -f default.conf.bak