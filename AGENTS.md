# AGENTS.md — Droplet Compose

Operational rules and system contracts for AI agents managing the DigitalOcean production stack.

---

## Environment Variables Contract (`.env`)

Every variable in `.env` is essential for production execution:

* `GITHUB_OWNER`: Lowercase GitHub username/owner (`serathian`) for resolving `ghcr.io/${GITHUB_OWNER}/*`.
* `ACME_EMAIL`: Administrator email for Let's Encrypt TLS notifications and cert registration.
* `TRAEFIK_DASHBOARD_AUTH`: `admin:<hashed-password>` for Traefik dashboard basic auth at `dns.jake-reddy.com`.
* `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`: Database credentials for the PostGIS container (used to compose `DATABASE_URL` and `DATABASE_URI` for `basecamp`).
* `PAYLOAD_SECRET`: 64-char hex secret for Payload CMS cookie hashing and JWT signing.
* `WATCHTOWER_TOKEN`: Secret Bearer token authenticating webhook deploy triggers from GitHub Actions.
* `CMS_API_INTERNAL`: Set to `http://basecamp:3000/api` for server-side fetches within the Docker network (also mapped to `NUXT_CMS_API_INTERNAL` for `nerdintheforest` Nuxt 3 runtime config).
* `NEXT_PUBLIC_CMS_URL`: Set to `https://basecamp.jake-reddy.com` for public CMS references.
* `S3_BUCKET`, `S3_REGION`, `S3_ENDPOINT`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_PUBLIC_URL`, `S3_FORCE_PATH_STYLE`, `S3_ACL`: Optional hot S3 + CDN storage for `basecamp` uploads (`nitf_media`, `jr_media`); if `S3_BUCKET` is unset, `basecamp` falls back to `/app/media`.
* `BACKUP_S3_BUCKET`, `BACKUP_S3_REGION`, `BACKUP_S3_ENDPOINT`, `BACKUP_S3_ACCESS_KEY_ID`, `BACKUP_S3_SECRET_ACCESS_KEY`, `BACKUP_S3_PREFIX`, `BACKUP_S3_STORAGE_CLASS`, `BACKUP_SCHEDULE`, `BACKUP_RETENTION_DAYS`: Optional cold S3 `pg_dump` + `traefik/acme.json` backup config for the `backup` service.

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

---

## Agent skills

### Issue tracker

Issues are tracked centrally in GitHub Issues (`Serathian/website-stack` via `gh --repo Serathian/website-stack`). See `docs/agents/issue-tracker.md`.

### Triage labels

Uses the default five-role triage label vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout (`GLOSSARY.md` + `docs/adr/` at the repo root). See `docs/agents/domain.md`.

