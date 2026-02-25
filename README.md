# droplet-compose

Docker Compose stack for the DigitalOcean droplet.

## Services

| Container | Image | Domain |
|-----------|-------|--------|
| `traefik` | `traefik:v2.11` | (reverse proxy, ports 80/443) |
| `jake-reddy` | `ghcr.io/<owner>/jake-reddy.com-backend:latest` | `jake-reddy.com` |
| `lastlightexplorer` | `ghcr.io/<owner>/lastlightexplorer:latest` | `explorer.jake-reddy.com` |
| `wordpress` | `wordpress:latest` | `reddyontheroad.com` |
| `mysql` | `mysql:8` | (internal only) |

## Setup (fresh droplet)

1. Copy `.env.example` → `.env` and fill in all values.
2. Run `startup.sh` as root (or paste into DO User Data).

## Updating a service

```bash
cd /opt/droplet-compose
docker compose pull <service>   # pull specific image
docker compose up -d <service>  # restart with new image
# or update everything:
docker compose pull && docker compose up -d
```

## Network isolation

- `traefik-public`: shared between Traefik and all proxied app containers
- `wordpress-internal`: WordPress ↔ MySQL only — MySQL is unreachable from all other containers
