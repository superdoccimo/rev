# DNS-01 with Cloudflare (Minimal Sample)

ワイルドカードや CDN/WAF 前段で HTTP-01 が通らない場合のための最小構成です。

## 前提
- Cloudflare 管理のゾーン
- API Token（`Zone.DNS Edit` 権限、対象ゾーンに限定推奨）
- Docker が利用可能

## 手順（最小）
1) Cloudflare API Token を発行（権限: Zone.DNS Edit、ゾーン限定）
2) `./certbot/conf/cloudflare.ini` を作成（ファイル権限 600）

```
dns_cloudflare_api_token = <YOUR_API_TOKEN>
```

3) 取得実行（例: `*.example.com` + `example.com`）

```bash
docker run --rm \
  -v "$PWD/certbot/conf:/etc/letsencrypt" \
  -v "$PWD/certbot/www:/var/www/certbot" \
  -v "$PWD/certbot/conf/cloudflare.ini:/cloudflare.ini:ro" \
  certbot/dns-cloudflare certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials /cloudflare.ini \
    -d example.com -d "*.example.com" \
    --email you@example.com --agree-tos --non-interactive
```

4) Nginx に反映
- `ssl_certificate`/`ssl_certificate_key` を `certbot/conf/live/<domain>/` に向ける
- `nginx -t && nginx -s reload`（init スクリプトと同様の手順）

## 更新（renew）
- `renew.sh` は `certbot renew` を実行します。DNS-01 設定はプラグイン/ini を自動検出します。
- 失敗時: `docker compose logs nginx-proxy` や `docker logs <certbot-container>` を確認

## 注意
- DNS 伝播レイテンシで発行が HTTP-01 より長引くことがあります。
- API Token を 600 で保護。リポジトリに含めない（`.gitignore` 推奨）。

