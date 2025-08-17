# Security Notes

## Threat model (high-level)
- Reverse-proxy termination on 80/443; upstream over internal network/Docker DNS
- TLS private keys on host (`certbot/conf`); backup & permission hygiene required
- Container boundary hardening: read-only FS, cap_drop, no-new-privileges

## Checklist (pre-production)
- [ ] Pin image versions (e.g., `nginx:1.27-alpine`)
- [ ] `read_only: true`, `tmpfs` for `/var/run`, `/var/cache/nginx`
- [ ] `cap_drop: ["ALL"]`, `cap_add: ["NET_BIND_SERVICE"]`
- [ ] `security_opt: ["no-new-privileges:true"]`
- [ ] Keys: `600`, Chain: `644`, Dirs: `755`
- [ ] Backups for `certbot/conf` (offsite encrypted)
- [ ] HSTS max-age chosen carefully; preload only if sure
- [ ] CSP tuned per app; consider `-Report-Only` rollout
- [ ] Renewal monitored (cron/systemd timer with logs)

