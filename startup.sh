#!/bin/bash
# Run once on a fresh Ubuntu 22.04/24.04 droplet as root.
#
# Usage:
#   1. SSH into droplet as root
#   2. git clone https://github.com/Serathian/droplet-compose /root/droplet-compose
#   3. scp .env root@DROPLET_IP:/root/droplet-compose/.env
#   4. bash /root/droplet-compose/startup.sh
set -e

DEPLOY_USER="deploy"
REPO_DIR="/home/${DEPLOY_USER}/droplet-compose"

# 1. Install Docker
echo "Installing Docker..."
apt-get update -y
apt-get install -y docker.io docker-compose-plugin
systemctl enable docker
systemctl start docker

# 2. Create deploy user and add to docker group
if ! id "$DEPLOY_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$DEPLOY_USER"
  echo "Created user: $DEPLOY_USER"
fi
usermod -aG docker "$DEPLOY_USER"

# 3. Move repo to deploy user's home and fix ownership
if [ -d /root/droplet-compose ] && [ "/root/droplet-compose" != "$REPO_DIR" ]; then
  mv /root/droplet-compose "$REPO_DIR"
fi
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "$REPO_DIR"

# 4. Copy SSH authorized_keys so you can login as deploy
DEPLOY_SSH="/home/${DEPLOY_USER}/.ssh"
mkdir -p "$DEPLOY_SSH"
cp /root/.ssh/authorized_keys "$DEPLOY_SSH/authorized_keys"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "$DEPLOY_SSH"
chmod 700 "$DEPLOY_SSH"
chmod 600 "$DEPLOY_SSH/authorized_keys"

# 5. Verify .env exists
if [ ! -f "${REPO_DIR}/.env" ]; then
  echo "ERROR: .env not found at ${REPO_DIR}/.env — copy it and re-run."
  exit 1
fi

# 6. Create acme.json for Traefik TLS certs (must be chmod 600)
touch "${REPO_DIR}/traefik/acme.json"
chmod 600 "${REPO_DIR}/traefik/acme.json"
chown "${DEPLOY_USER}:${DEPLOY_USER}" "${REPO_DIR}/traefik/acme.json"

# 7. Authenticate with GHCR as deploy user so Watchtower can pull private images
echo "Enter your GitHub PAT (read:packages scope):"
read -s GITHUB_TOKEN
echo "Enter your GitHub username:"
read GITHUB_OWNER
su - "$DEPLOY_USER" -c "echo '${GITHUB_TOKEN}' | docker login ghcr.io -u '${GITHUB_OWNER}' --password-stdin"

# 8. Pull images and start the stack as deploy user
echo "Starting stack..."
su - "$DEPLOY_USER" -c "cd ${REPO_DIR} && docker compose pull && docker compose up -d"

echo ""
echo "Done! Stack is up."
echo "You can now SSH in as: ${DEPLOY_USER}@$(hostname -I | awk '{print $1}')"
echo "Run 'docker compose ps' to verify services."
