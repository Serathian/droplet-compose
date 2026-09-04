# droplet-compose

Docker Compose stack for the DigitalOcean droplet.

## Services

| Container | Image | Domain |
|-----------|-------|--------|
| `traefik` | `traefik:v2.11` | Reverse proxy, ports 80/443, auto-HTTPS |
| `jake-reddy` | `ghcr.io/<owner>/jake-reddy.com-backend:latest` | `jake-reddy.com` |
| `lastlightexplorer` | `ghcr.io/<owner>/lastlightexplorer:latest` | `explorer.jake-reddy.com` |
| `30th-at-33` | `ghcr.io/<owner>/30th-at-33:latest` | `30plus3.jake-reddy.com` |
| `houseforce` | `ghcr.io/<owner>/houseforce:latest` | `houseforce.jake-reddy.com`, `houseforce-blog...` |
| `watchtower` | `containrrr/watchtower` | Auto-updates containers via push webhooks |

## The `deploy` User

For security, this stack does **not** run as `root`. 
The `startup.sh` script automatically provisions a non-root `deploy` user, adds it to the `docker` group, and copies your SSH keys to it.

All day-to-day operations and `docker-compose` commands **must be run as the `deploy` user**. 
The repository is stored at `/home/deploy/droplet-compose`.

## Fresh Droplet Setup

1. **SSH into the fresh droplet as `root`**.
2. Clone this repository:
   ```bash
   git clone https://github.com/<your-username>/droplet-compose /root/droplet-compose
   ```
3. Run the interactive startup script (must be run as `root` the first time):
   ```bash
   bash /root/droplet-compose/startup.sh
   ```
4. **The script will automatically:**
   - Install Docker & Docker Compose
   - Create the `deploy` user and secure it with your SSH keys
   - Prompt you for your GitHub credentials and Traefik dashboard password
   - Auto-generate secure tokens and hashes for Watchtower and Traefik
   - Generate your `.env` file automatically
   - Log into GitHub Container Registry as the `deploy` user
   - Launch the stack!
   - Prune unused Docker images to save disk space
   - Echo out the Watchtower token, Traefik dashboard URL, and database credentials

5. You can now log out of `root` and **SSH back in as `deploy`**:
   ```bash
   ssh deploy@<DROPLET_IP>
   cd ~/droplet-compose
   ```

> **DNS must point to the droplet IP before first start** — Traefik uses TLS challenges to issue Let's Encrypt certs.

## Day-to-Day Commands (Run as `deploy`)

```bash
docker compose pull && docker compose up -d   # pull latest images + restart changed containers
docker image prune -af                        # prune all unused docker images
docker compose logs -f                        # tail all logs
docker compose logs -f jake-reddy             # tail one service
docker compose ps                             # show container status
docker compose restart traefik                # restart one service
```

## Auto-Updates via Watchtower

Watchtower is configured to receive push webhooks from GitHub Actions, instantly triggering an update when a new image is pushed to GHCR (no polling delays).

Watchtower uses the `deploy` user's Docker auth config (`/home/deploy/.docker/config.json`) to authenticate with GHCR. This is automatically configured during `startup.sh`.

If you ever need to manually rotate your GitHub Personal Access Token, log in as the `deploy` user and run:
```bash
docker login ghcr.io -u <YOUR_GITHUB_USERNAME>
```
