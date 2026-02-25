# droplet-compose

Docker Compose stack for the DigitalOcean droplet.

## Services

| Container | Image | Domain |
|-----------|-------|--------|
| `traefik` | `traefik:v2.11` | Reverse proxy, ports 80/443, auto-HTTPS |
| `jake-reddy` | `ghcr.io/<owner>/jake-reddy.com-backend:latest` | `jake-reddy.com` |
| `lastlightexplorer` | `ghcr.io/<owner>/lastlightexplorer:latest` | `explorer.jake-reddy.com` |
| `wordpress` | `wordpress:latest` | `reddyontheroad.com` |
| `mysql` | `mysql:8` | Internal only |
| `watchtower` | `containrrr/watchtower` | Polls GHCR every 5 min, auto-restarts on new images |

## Network Isolation

- `traefik-public`: shared between Traefik and all proxied app containers
- `wordpress-internal`: WordPress ↔ MySQL only — MySQL unreachable from all other services

## Fresh Droplet Setup

1. Copy `.env.example` → `.env` on the droplet and fill in all values.
2. Set `GITHUB_TOKEN` and `GITHUB_OWNER` env vars (or edit `startup.sh`).
3. Run:
   ```bash
   bash startup.sh
   ```

> **DNS must point to the droplet IP before first start** — Traefik uses TLS challenges to issue Let's Encrypt certs.

## Day-to-Day Commands

```bash
make update           # pull latest images + restart changed containers
make logs             # tail all logs
make logs s=jake-reddy  # tail one service
make ps               # show container status
make restart s=wordpress  # restart one service
```

## Auto-Updates via Watchtower

When GitHub Actions pushes a new image to GHCR (on push to `main`/`master`), Watchtower detects the new digest within 5 minutes and automatically restarts the affected container — no manual SSH required.

Watchtower uses `/root/.docker/config.json` for GHCR auth. Run `make login` once after provisioning (or after token rotation).

## Manual Update

```bash
make update
# or explicitly:
docker compose pull && docker compose up -d
```
