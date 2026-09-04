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

# 1. Install Docker (only if not already installed)
if ! command -v docker &> /dev/null; then
  echo "Installing Docker..."
  apt-get update -y
  apt-get install -y docker.io docker-compose-v2
  systemctl enable docker
  systemctl start docker
else
  echo "Docker is already installed, skipping installation."
fi

# 2. Create deploy user and add to docker group
if ! id "$DEPLOY_USER" &>/dev/null; then
  useradd -m -s /bin/bash "$DEPLOY_USER"
  echo "Created user: $DEPLOY_USER"
fi
usermod -aG docker "$DEPLOY_USER"

# 3. Move repo to deploy user's home and fix ownership
if [ -d /root/droplet-compose ] && [ "/root/droplet-compose" != "$REPO_DIR" ]; then
  mkdir -p "$REPO_DIR"
  cp -a /root/droplet-compose/. "$REPO_DIR/"
  rm -rf /root/droplet-compose
fi
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "$REPO_DIR"

# 4. Copy SSH authorized_keys so you can login as deploy
DEPLOY_SSH="/home/${DEPLOY_USER}/.ssh"
mkdir -p "$DEPLOY_SSH"
cp /root/.ssh/authorized_keys "$DEPLOY_SSH/authorized_keys"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "$DEPLOY_SSH"
chmod 700 "$DEPLOY_SSH"
chmod 600 "$DEPLOY_SSH/authorized_keys"

# 5. Generate .env file if it doesn't exist
if [ ! -f "${REPO_DIR}/.env" ]; then
  echo "=== Environment Setup ==="
  
  echo "Enter your GitHub username:"
  read -r GITHUB_OWNER
  
  echo "Enter your GitHub PAT (read:packages scope) for Watchtower:"
  read -rs GITHUB_TOKEN
  echo ""
  
  echo "Enter your Let's Encrypt Email (for SSL certs):"
  read -r ACME_EMAIL
  
  echo "Enter a password for the Traefik dashboard (user: admin):"
  read -rs TRAEFIK_PASSWORD
  echo ""
  
  echo "Generating Traefik dashboard auth hash..."
  # Generate bcrypt hash and escape the dollar signs for docker-compose
  TRAEFIK_HASH=$(docker run --rm httpd:alpine htpasswd -bnBC 10 admin "${TRAEFIK_PASSWORD}" | sed -e 's/\$/\$\$/g')
  
  echo "Generating secure Watchtower token..."
  WATCHTOWER_TOKEN=$(openssl rand -hex 32)
  
  echo "Generating Houseforce Strapi CMS secure keys and DB credentials..."
  HOUSEFORCE_STRAPI_APP_KEYS="$(openssl rand -base64 16),$(openssl rand -base64 16)"
  HOUSEFORCE_STRAPI_API_TOKEN_SALT=$(openssl rand -base64 16)
  HOUSEFORCE_STRAPI_ADMIN_JWT_SECRET=$(openssl rand -base64 16)
  HOUSEFORCE_STRAPI_TRANSFER_TOKEN_SALT=$(openssl rand -base64 16)
  HOUSEFORCE_STRAPI_JWT_SECRET=$(openssl rand -base64 16)
  HOUSEFORCE_DB_NAME="strapi_$(openssl rand -hex 4)"
  HOUSEFORCE_DB_USER="strapi_$(openssl rand -hex 4)"
  HOUSEFORCE_DB_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9')
  
  echo "Generating Basecamp Payload CMS secure keys and DB credentials..."
  BASECAMP_PAYLOAD_SECRET=$(openssl rand -hex 32)
  BASECAMP_DB_NAME="payload_$(openssl rand -hex 4)"
  BASECAMP_DB_USER="user_$(openssl rand -hex 4)"
  BASECAMP_DB_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9')
  
  cat <<EOF > "${REPO_DIR}/.env"
# Your GitHub username (used to pull images from GHCR)
GITHUB_OWNER=${GITHUB_OWNER}

# Email for Let's Encrypt certificate registration
ACME_EMAIL=${ACME_EMAIL}

# Traefik dashboard basic auth
TRAEFIK_DASHBOARD_AUTH=${TRAEFIK_HASH}

# Secret token for triggering Watchtower webhooks
WATCHTOWER_TOKEN=${WATCHTOWER_TOKEN}

# ---------------------------------------------------
# Houseforce (Strapi CMS + Next.js)
# ---------------------------------------------------
HOUSEFORCE_NEXT_PUBLIC_STRAPI_URL=https://cms.jake-reddy.com
HOUSEFORCE_STRAPI_APP_KEYS=${HOUSEFORCE_STRAPI_APP_KEYS}
HOUSEFORCE_STRAPI_API_TOKEN_SALT=${HOUSEFORCE_STRAPI_API_TOKEN_SALT}
HOUSEFORCE_STRAPI_ADMIN_JWT_SECRET=${HOUSEFORCE_STRAPI_ADMIN_JWT_SECRET}
HOUSEFORCE_STRAPI_TRANSFER_TOKEN_SALT=${HOUSEFORCE_STRAPI_TRANSFER_TOKEN_SALT}
HOUSEFORCE_STRAPI_JWT_SECRET=${HOUSEFORCE_STRAPI_JWT_SECRET}
HOUSEFORCE_DB_NAME=${HOUSEFORCE_DB_NAME}
HOUSEFORCE_DB_USER=${HOUSEFORCE_DB_USER}
HOUSEFORCE_DB_PASSWORD=${HOUSEFORCE_DB_PASSWORD}

# ---------------------------------------------------
# Basecamp (Payload CMS + PostgreSQL)
# ---------------------------------------------------
BASECAMP_PAYLOAD_SECRET=${BASECAMP_PAYLOAD_SECRET}
BASECAMP_DB_NAME=${BASECAMP_DB_NAME}
BASECAMP_DB_USER=${BASECAMP_DB_USER}
BASECAMP_DB_PASSWORD=${BASECAMP_DB_PASSWORD}

# ---------------------------------------------------
# You can add your backend (jake-reddy.com) variables 
# below manually later (SMTP_HOST, RECAPTCHA_SECRET, etc)
# ---------------------------------------------------
EOF
  chown "${DEPLOY_USER}:${DEPLOY_USER}" "${REPO_DIR}/.env"
  chmod 600 "${REPO_DIR}/.env"
  echo "Created .env file securely."
else
  # If .env exists, we just need to make sure we still log into ghcr.io
  # if they haven't already. But for simplicity, we'll prompt for token if missing.
  echo ".env file already exists. Skipping generation."
  source "${REPO_DIR}/.env"
  
  echo "Enter your GitHub PAT (read:packages scope) to login Watchtower (or press enter to skip if already logged in):"
  read -rs GITHUB_TOKEN
  echo ""
fi

# 6. Create acme.json for Traefik TLS certs (must be chmod 600)
# Make sure the traefik directory exists first
mkdir -p "${REPO_DIR}/traefik"
touch "${REPO_DIR}/traefik/acme.json"
chmod 600 "${REPO_DIR}/traefik/acme.json"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${REPO_DIR}/traefik"

# 7. Authenticate with GHCR as deploy user so Watchtower can pull private images
# CRITICAL: Ensure config.json exists as a file BEFORE compose starts, even if we skip login, 
# otherwise Docker will mistakenly create it as a directory!
su - "$DEPLOY_USER" -c "mkdir -p ~/.docker && if [ ! -f ~/.docker/config.json ]; then echo '{}' > ~/.docker/config.json; fi"

if [ -n "$GITHUB_TOKEN" ]; then
  echo "Logging into ghcr.io..."
  su - "$DEPLOY_USER" -c "echo '${GITHUB_TOKEN}' | docker login ghcr.io -u '${GITHUB_OWNER}' --password-stdin"
fi

# 8. Pull images and start the stack as deploy user
echo "Starting stack..."
su - "$DEPLOY_USER" -c "cd ${REPO_DIR} && docker compose pull && docker compose up -d"

echo ""
echo "Done! Stack is up."
echo "You can now SSH in as: ${DEPLOY_USER}@$(hostname -I | awk '{print $1}')"
echo "Run 'docker compose ps' to verify services."
