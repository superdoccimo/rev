SHELL := /bin/bash
-include .env

NGINX_CONTAINER ?= proxy-nginx

.PHONY: up down logs init renew test diag

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f $(NGINX_CONTAINER)

init:   ## first obtain certs & write https config safely
	./scripts/preflight.sh
	./init-letsencrypt.sh

renew:  ## renew + reload nginx
	./renew.sh

test:   ## validate nginx config inside container
	docker exec $(NGINX_CONTAINER) nginx -t

diag:   ## quick diagnostics for HTTP-01 path
	@FIRST=$$(echo "$$DOMAINS" | awk '{print $$1}'); \
	echo "Testing http://$$FIRST/.well-known/acme-challenge/"; \
	curl -I --max-time 5 "http://$$FIRST/.well-known/acme-challenge/" || true

