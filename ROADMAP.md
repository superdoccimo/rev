# Roadmap

## Near-term (Now ~ 2 weeks)
- [A] Multi-domain strategy guide (SAN vs split) — finalize and link from README
- [B] DNS-01 (Cloudflare) minimal sample — script + docs
- CSP examples (strict/relaxed) + pitfalls (HSTS preload cannot be undone)

## Mid-term (1 ~ 2 months)
- Systemd timer unit sample (optional) with journald logging
- Template-ization (`envsubst` or gomplate) for upstream/TLS params
- Optional runtime lockdown presets in `docker-compose.yml` (cap_drop, tmpfs, read_only)

## Long-term
- Provider-agnostic DNS-01 abstraction (lego/acme.sh comparison)
- L7 WAF/CDN patterns cookbook (zero-downtime behind CDN)

