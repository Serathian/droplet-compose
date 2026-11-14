# AGENTS.md — Droplet Compose

Operational rules and system contracts for AI agents managing the DigitalOcean production stack.

---

## Environment Variables Contract (`.env`)

Every variable in `.env` is essential for production execution:

* `GITHUB_OWNER`: GitHub username (`Serathian`) for resolving `ghcr.io/${GITHUB_OWNER}/*`.
* `ACME_EMAIL`: Administrator email for Let's Encrypt TLS notifications and cert registration.
* `TRAEFIK_DASHBOARD_AUTH`: `admin:<hashed-password>` for Traefik dashboard basic auth at `dns.jake-reddy.com`.
* `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`: Database credentials for the PostGIS container.
* `PAYLOAD_SECRET`: 64-char hex secret for Payload CMS cookie hashing and JWT signing.
* `WATCHTOWER_TOKEN`: Secret Bearer token authenticating webhook deploy triggers from GitHub Actions.
* `CMS_API_INTERNAL`: Set to `http://basecamp:3000/api` for server-side fetches within Docker network.

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
