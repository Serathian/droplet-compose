#!/bin/bash
# Droplet startup / cloud-init script
# Run once on a fresh Ubuntu 22.04 droplet to bring up the full stack.
# Pass secrets via DigitalOcean User Data or copy .env manually before running.
set -e

# 1. Install Docker
apt-get update -y
apt-get install -y docker.io docker-compose-plugin git
systemctl enable docker
systemctl start docker

# 2. Clone the droplet-compose repo
REPO_URL="${DROPLET_COMPOSE_REPO:-https://github.com/YOUR_GITHUB_USERNAME/droplet-compose.git}"
git clone "$REPO_URL" /opt/droplet-compose

# 3. Create the acme.json file for Traefik TLS certs (must be chmod 600)
touch /opt/droplet-compose/traefik/acme.json
chmod 600 /opt/droplet-compose/traefik/acme.json

# 4. Place your .env file at /opt/droplet-compose/.env before running this step.
#    You can inject it via DigitalOcean User Data or copy it after first boot:
#      scp .env root@YOUR_DROPLET_IP:/opt/droplet-compose/.env
if [ ! -f /opt/droplet-compose/.env ]; then
  echo "ERROR: /opt/droplet-compose/.env not found. Copy your .env file and re-run step 5."
  exit 1
fi

# 5. Pull images and start the stack
cd /opt/droplet-compose
docker compose pull
docker compose up -d

echo "Stack is up. Run 'docker compose ps' to verify."
