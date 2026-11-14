---
name: deploy-ops
description: >-
  Procedures for managing, monitoring, troubleshooting, and verifying production deployments on the DigitalOcean Droplet running droplet-compose. Use when verifying container health, debugging Traefik TLS errors, inspecting logs, or manually triggering rolling restarts.
---

# Deploy Operations Skill

Use this skill when managing the live droplet deployment or troubleshooting production issues.

## 1. Checking Deployment Health

On the Droplet (or via SSH):

```bash
cd /home/deploy/droplet-compose

# 1. Check all container states and uptime
docker compose ps

# 2. Check Traefik routing and certificate renewals
docker compose logs --tail 50 traefik

# 3. Check Basecamp CMS and database connections
docker compose logs --tail 50 basecamp
docker compose logs --tail 50 postgres

# 4. Check Watchtower webhook activity
docker compose logs --tail 50 watchtower
```

## 2. Triggering a Manual Deployment

If you need to pull and restart containers manually without waiting for CI or Watchtower:

```bash
# Pull all latest public images
docker compose pull

# Gracefully recreate any containers that have new images
docker compose up -d

# Verify zero downtime restart
docker compose ps
```

To target a single service (e.g. only `basecamp`):
```bash
docker compose pull basecamp
docker compose up -d basecamp
```

## 3. Testing Watchtower Webhook Manually

From any terminal with access to `https://watchtower.jake-reddy.com`:

```bash
curl -i -X POST \
  -H "Authorization: Bearer <WATCHTOWER_TOKEN>" \
  https://watchtower.jake-reddy.com/v1/update
```
Expected response: `HTTP/1.1 200 OK`

## 4. Recovering from Common Failures

* **Traefik ACME permissions error**:
  ```bash
  chmod 600 traefik/acme.json
  docker compose restart traefik
  ```
* **Database lock or connection refusal**:
  Check if `postgres` is healthy:
  ```bash
  docker compose exec postgres pg_isready -U payload -d payload
  ```
* **Container crashing on startup**:
  Inspect exit codes and stderr:
  ```bash
  docker compose logs <container-name>
  ```
