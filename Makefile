COMPOSE = docker compose

.PHONY: up down restart update logs ps pull login

## Start the full stack
up:
	$(COMPOSE) up -d

## Stop all services
down:
	$(COMPOSE) down

## Restart a specific service: make restart s=jake-reddy
restart:
	$(COMPOSE) restart $(s)

## Pull latest images and restart changed containers
update:
	$(COMPOSE) pull && $(COMPOSE) up -d

## Follow logs (all services, or specify: make logs s=jake-reddy)
logs:
	$(COMPOSE) logs -f $(s)

## Show running containers and their status
ps:
	$(COMPOSE) ps

## Authenticate with GHCR (run once per droplet, or after token rotation)
## Usage: GITHUB_TOKEN=xxx GITHUB_OWNER=xxx make login
login:
	@echo "$(GITHUB_TOKEN)" | docker login ghcr.io -u "$(GITHUB_OWNER)" --password-stdin
