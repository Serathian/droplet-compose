# Droplet Compose — Agent Instructions

`droplet-compose` is the **final deliverable product** of the website stack. It orchestrates all containerized applications, databases, reverse proxying, and automated continuous deployment onto a single Ubuntu DigitalOcean Droplet.

---

## 1. Golden Rules for Deployment Infrastructure

1. **All App Images Are Public**:
   * All production images (`ghcr.io/Serathian/*`) are published publicly.
   * Never re-introduce authentication dependencies, PAT prompts, or `/root/.docker/config.json` volume mounts on the droplet.
2. **PostGIS is Mandatory**:
   * The database image is `postgis/postgis:16-3.4-alpine`. Never change it to generic `postgres:alpine`, or CMS migrations will fail.
3. **Automated Migration Runner**:
   * `basecamp-cms` runs `payload migrate` automatically via `docker-entrypoint.sh` before the Node server starts. You do not need to manually run migrations on the server.
4. **Network Segregation**:
   * Only Traefik and public apps attach to `traefik-public`.
   * Postgres and Payload CMS communicate exclusively over `cms-internal`.
   * Port 5432 is never exposed externally.

---

## 2. Service Inventory & Traefik Routing

| Service Name | Port | Host Rules | TLS Resolver |
| :--- | :--- | :--- | :--- |
| `traefik` | 80, 443 | `dns.jake-reddy.com` (Dashboard) | Let's Encrypt (`le`) |
| `basecamp` | 3000 | `basecamp.jake-reddy.com` | `le` |
| `jake-reddy` | 3000 | `jake-reddy.com`, `www.jake-reddy.com` | `le` |
| `nerdintheforest` | 3000 | `nerdintheforest.com`, `www.nerdintheforest.com` | `le` |
| `reddyontheroad` | 3000 | `reddyontheroad.com`, `www.reddyontheroad.com` | `le` |
| `lastlightexplorer` | 80 | `explorer.jake-reddy.com` | `le` |
| `watchtower` | 8080 | `watchtower.jake-reddy.com` | `le` |
| `postgres` | 5432 | internal only | — |

---

## 3. Deployment Flow

1. Developer pushes to `main`/`master` in any app repository.
2. GitHub Actions runs CI, builds the Docker image, and pushes to `ghcr.io/Serathian/<app>:latest`.
3. GitHub Actions triggers the Watchtower webhook:
   ```bash
   POST https://watchtower.jake-reddy.com/v1/update
   Header: Authorization: Bearer <WATCHTOWER_TOKEN>
   ```
4. Watchtower immediately pulls the new public image from GHCR and gracefully restarts the container.
5. If the webhook is not received, Watchtower falls back to hourly periodic polling (`WATCHTOWER_POLL_INTERVAL=3600`).
