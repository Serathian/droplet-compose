# droplet-compose

Production Docker Compose orchestration for the multi-site website stack running on a DigitalOcean Droplet.

---

## Services & Architecture

| Container | Image | Port / Route | Domain | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `traefik` | `traefik:v2.11` | 80, 443 | `dns.jake-reddy.com` | Edge router, TLS termination (Let's Encrypt), basic auth dashboard |
| `basecamp` | `ghcr.io/${GITHUB_OWNER}/basecamp-cms:latest` | 3000 (internal) | `basecamp.jake-reddy.com` | Headless Payload CMS backend (auto-runs migrations on startup) |
| `postgres` | `postgis/postgis:16-3.4-alpine` | 5432 (internal) | — | PostGIS spatial database for Payload CMS |
| `jake-reddy` | `ghcr.io/${GITHUB_OWNER}/jake-reddy.com:latest` | 3000 / 80 | `jake-reddy.com`, `www.jake-reddy.com` | Personal portfolio & blog frontend (Astro / Nginx) |
| `nerdintheforest` | `ghcr.io/${GITHUB_OWNER}/nerdintheforest.com:latest` | 3000 (internal) | `nerdintheforest.com`, `www.nerdintheforest.com` | Outdoor trail & GIS map app (Nuxt 3) |
| `reddyontheroad` | `ghcr.io/${GITHUB_OWNER}/reddyontheroad.com:latest` | 3000 (internal) | `reddyontheroad.com`, `www.reddyontheroad.com` | Travel journal & overland scrapbook (Next.js - WIP landing page) |
| `lastlightexplorer`| `ghcr.io/${GITHUB_OWNER}/lastlightexplorer:latest` | 80 (internal) | `explorer.jake-reddy.com` | Board game companion mini app (Vite / Nginx) |
| `watchtower` | `containrrr/watchtower` | — | — | Automated continuous deployment; polls GHCR every 5m |

---

## Network Isolation

* **`traefik-public`**: Public ingress network connecting Traefik to all customer-facing apps (`basecamp`, `jake-reddy`, `nerdintheforest`, `reddyontheroad`, `lastlightexplorer`).
* **`cms-internal`**: Private network strictly between `basecamp` and `postgres`. Database port 5432 is never exposed to the public internet.

---

## Initial Droplet Provisioning

### 1. Prerequisites (DNS)
Before launching the stack, point DNS `A` records to your droplet IP:
* `jake-reddy.com`, `www.jake-reddy.com`
* `basecamp.jake-reddy.com`
* `nerdintheforest.com`, `www.nerdintheforest.com`
* `reddyontheroad.com`, `www.reddyontheroad.com`
* `explorer.jake-reddy.com`
* `watchtower.jake-reddy.com` (deployment webhook)
* `dns.jake-reddy.com` (Traefik dashboard)

### 2. Setup on the Droplet

1. Clone or copy `droplet-compose` to `/home/deploy/droplet-compose` (or `/root/droplet-compose`):
   ```bash
   git clone git@github.com:Serathian/droplet-compose.git /home/deploy/droplet-compose
   cd /home/deploy/droplet-compose
   ```
2. Copy environment file and fill in values:
   ```bash
   cp .env.example .env
   # Edit .env: set POSTGRES_PASSWORD, PAYLOAD_SECRET, WATCHTOWER_TOKEN, ACME_EMAIL, GITHUB_OWNER
   ```
3. Prepare Traefik ACME storage:
   ```bash
   mkdir -p traefik
   touch traefik/acme.json
   chmod 600 traefik/acme.json
   ```
4. Launch the stack (images are public on GHCR, no Docker login or PAT required):
   ```bash
   docker compose pull
   docker compose up -d
   ```

---

## Continuous Deployment via Watchtower Webhook

Watchtower runs with its HTTP API enabled on port 8080 and reverse-proxied by Traefik with TLS.

* **Webhook Trigger (Instant Deploy)**:
  When a GitHub Actions pipeline completes a build, it fires an authenticated webhook request:
  ```bash
  curl -X POST \
    -H "Authorization: Bearer <WATCHTOWER_TOKEN>" \
    https://watchtower.jake-reddy.com/v1/update
  ```
  Watchtower immediately pulls the updated public image and gracefully restarts the container within seconds.
* **Hourly Polling Fallback**:
  Watchtower also runs an hourly periodic poll (`WATCHTOWER_POLL_INTERVAL=3600`) as a safety net.
* **Auto-Cleanup**:
  Old image layers are pruned automatically upon restart (`WATCHTOWER_CLEANUP=true`).

---

## Operational Commands

```bash
# View running status of all containers
docker compose ps

# Follow logs across the entire stack
docker compose logs -f

# Follow logs for a specific service
docker compose logs -f basecamp
docker compose logs -f traefik
docker compose logs -f watchtower

# Manually trigger a pull and restart of all or single services
docker compose pull
docker compose up -d

# Restart a specific service
docker compose restart basecamp
```
