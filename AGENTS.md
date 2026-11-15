# AGENTS.md — Droplet Compose

Operational rules and system contracts for AI agents managing the DigitalOcean production stack.

---

## Environment Variables Contract (`.env`)

Every variable in `.env` is essential for production execution:

* `GITHUB_OWNER`: GitHub username (`Serathian`) for resolving `ghcr.io/${GITHUB_OWNER}/*`.
* `ACME_EMAIL`: Administrator email for Let's Encrypt TLS notifications and cert registration.
* `TRAEFIK_DASHBOARD_AUTH`: `admin:<hashed-password>` for Traefik dashboard basic auth at `dns.jake-reddy.com`.
* `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`: Database credentials for the PostGIS container (used to compose `DATABASE_URL` and `DATABASE_URI` for `basecamp`).
* `PAYLOAD_SECRET`: 64-char hex secret for Payload CMS cookie hashing and JWT signing.
* `WATCHTOWER_TOKEN`: Secret Bearer token authenticating webhook deploy triggers from GitHub Actions.
* `CMS_API_INTERNAL`: Set to `http://basecamp:3000/api` for server-side fetches within the Docker network (also mapped to `NUXT_CMS_API_INTERNAL` for `nerdintheforest` Nuxt 3 runtime config).
* `NEXT_PUBLIC_CMS_URL`: Set to `https://basecamp.jake-reddy.com` for public CMS references.

---

## Service Routing & Deployment Contract

* **Container Ports**: `jake-reddy` and `lastlightexplorer` serve Nginx on port `80`; `basecamp`, `nerdintheforest`, and `reddyontheroad` listen on port `3000`; `watchtower` exposes its webhook HTTP API on port `8080`.
* **Watchtower Polling**: Instant deployments trigger via `https://watchtower.jake-reddy.com/v1/update`, with hourly periodic polling fallback (`WATCHTOWER_POLL_INTERVAL=3600`, every 1 hour).
* **Active Branch**: `main` (`git clone https://github.com/Serathian/droplet-compose.git`).

---

## Safe Operation Guidelines

1. **Never run `docker compose down -v` in production**:
   * Volume `postgres-data` stores the live database.
   * Volume `basecamp-media` stores uploaded media assets.
   * Dropping volumes causes irreversible data loss.
2. **ACME Permission Requirement**:
   * The file `traefik/acme.json` must have strict `chmod 600` permissions.
   * If permissions are loose, Traefik refuses to start and fails TLS certificate generation.
3. **Database Migration Safety**:
   * Migrations run automatically on `basecamp` container start.
   * Never execute `npx payload migrate:fresh` on the droplet — it drops all tables.
   * Always verify `docker compose logs basecamp` after a deployment to ensure migrations completed cleanly.
