#!/bin/bash
# Run once on a fresh Ubuntu 22.04 droplet after cloning this repo and placing .env.
#
# Usage:
#   1. SSH into droplet
#   2. git clone https://github.com/jake-reddy/droplet-compose /opt/droplet-compose
#   3. scp .env root@DROPLET_IP:/opt/droplet-compose/.env
#   4. bash /opt/droplet-compose/startup.sh
set -e

# 1. Install Docker
apt-get update -y
apt-get install -y docker.io docker-compose-plugin
systemctl enable docker
systemctl start docker

# 2. Authenticate with GHCR so Watchtower can pull private images
echo "Enter your GitHub PAT (read:packages scope):"
read -s GITHUB_TOKEN
echo "Enter your GitHub username:"
read GITHUB_OWNER
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_OWNER" --password-stdin

# 3. Create acme.json for Traefik TLS certs (must be chmod 600)
touch /opt/droplet-compose/traefik/acme.json
chmod 600 /opt/droplet-compose/traefik/acme.json

# 4. Verify .env exists
if [ ! -f /opt/droplet-compose/.env ]; then
  echo "ERROR: .env not found at /opt/droplet-compose/.env — copy it and re-run."
  exit 1
fi

# 5. Pull images and start the stack
cd /opt/droplet-compose
docker compose pull
docker compose up -d

echo "Stack is up. Run 'docker compose ps' to verify."
