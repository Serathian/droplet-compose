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
SOURCE_DIR="/root/droplet-compose"
TARGET_BRANCH="main"

# 0. Verify repository and active branch before modifying the droplet
if [ -d "$SOURCE_DIR" ] && [ -d "$REPO_DIR" ] && [ "$SOURCE_DIR" != "$REPO_DIR" ]; then
  echo "ERROR: Both ${SOURCE_DIR} and ${REPO_DIR} exist; remove or consolidate one before re-running."
  exit 1
fi

ACTIVE_REPO="$REPO_DIR"
if [ -d "$SOURCE_DIR" ] && [ "$SOURCE_DIR" != "$REPO_DIR" ]; then
  ACTIVE_REPO="$SOURCE_DIR"
fi

if [ ! -d "$ACTIVE_REPO" ]; then
  echo "ERROR: Repository not found at ${SOURCE_DIR} or ${REPO_DIR}."
  echo "Clone it first: git clone -b ${TARGET_BRANCH} https://github.com/Serathian/droplet-compose ${SOURCE_DIR}"
  exit 1
fi

if [ -d "${ACTIVE_REPO}/.git" ] && command -v git >/dev/null 2>&1; then
  CURRENT_BRANCH="$(git -C "$ACTIVE_REPO" rev-parse --abbrev-ref HEAD)"
  if [ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ] && ! grep -q "basecamp:" "${ACTIVE_REPO}/docker-compose.yml" 2>/dev/null; then
    echo "ERROR: Repository at ${ACTIVE_REPO} is on branch '${CURRENT_BRANCH}' (legacy compose stack)."
    echo "Switch to '${TARGET_BRANCH}' first: git -C ${ACTIVE_REPO} fetch origin ${TARGET_BRANCH} && git -C ${ACTIVE_REPO} checkout ${TARGET_BRANCH}"
    exit 1
  fi
  if [ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]; then
    echo "WARNING: Repository at ${ACTIVE_REPO} is on branch '${CURRENT_BRANCH}' (expected '${TARGET_BRANCH}')."
  fi
fi

# 1. Install Docker
echo "Installing Docker..."
apt-get update -y
apt-get install -y docker.io docker-compose-v2
systemctl enable docker
systemctl start docker

# 2. Create deploy user and add to docker group
if ! id "$DEPLOY_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$DEPLOY_USER"
  echo "Created user: $DEPLOY_USER"
fi
usermod -aG docker "$DEPLOY_USER"

# 3. Move repo to deploy user's home and fix ownership
if [ -d "$SOURCE_DIR" ] && [ "$SOURCE_DIR" != "$REPO_DIR" ]; then
  mv "$SOURCE_DIR" "$REPO_DIR"
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

# 6. Create traefik directory and acme.json for Traefik TLS certs (must be chmod 600)
mkdir -p "${REPO_DIR}/traefik"
chown "${DEPLOY_USER}:${DEPLOY_USER}" "${REPO_DIR}/traefik"
touch "${REPO_DIR}/traefik/acme.json"
chmod 600 "${REPO_DIR}/traefik/acme.json"
chown "${DEPLOY_USER}:${DEPLOY_USER}" "${REPO_DIR}/traefik/acme.json"

# 7. Pull public images, build backup sidecar, and start the stack as deploy user
echo "Starting stack (pulling public GHCR images)..."
su - "$DEPLOY_USER" -c "cd ${REPO_DIR} && docker compose pull && docker compose up -d --build"

echo ""
echo "Done! Stack is up."
echo "You can now SSH in as: ${DEPLOY_USER}@$(hostname -I | awk '{print $1}')"
echo "Run 'docker compose ps' to verify services."
