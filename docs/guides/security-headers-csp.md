# Security Headers & CSP Examples

## 既定で有効（本リポジトリのテンプレ）
- HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy
- OCSP Stapling 有効化、TLS1.2/1.3、Session Tickets Off

## CSP（例）

Strict（ホワイトリスト運用）
```nginx
add_header Content-Security-Policy "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'" always;
```

Relaxed（CDN 併用など）
```nginx
add_header Content-Security-Policy "default-src 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline' https:; script-src 'self' https: 'unsafe-inline'; connect-src 'self' https:;" always;
```

### 注意点
- HSTS preload は戻しにくい（誤設定注意／徐々に適用）。
- CSP はアプリ要件に合わせて段階的に導入（`Content-Security-Policy-Report-Only` で試験可能）。

