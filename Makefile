ROOT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
COWRIE_DOCKER_COMPOSE := docker compose -p adids-honeypots -f "$(ROOT_DIR)/docker-compose.yml"

.PHONY: up
up:
	@mkdir -p "$(ROOT_DIR)/cowrie/var/log/cowrie" "$(ROOT_DIR)/cowrie/var/lib/cowrie" "$(ROOT_DIR)/data/logs/zeek/live/cowrie/current"
	@chmod 0777 "$(ROOT_DIR)/cowrie/var/log/cowrie" "$(ROOT_DIR)/cowrie/var/lib/cowrie" "$(ROOT_DIR)/data/logs/zeek/live/cowrie/current"
	@$(COWRIE_DOCKER_COMPOSE) up -d cowrie zeek-cowrie-live

.PHONY: down
down:
	@$(COWRIE_DOCKER_COMPOSE) down

.PHONY: ps
ps:
	@$(COWRIE_DOCKER_COMPOSE) ps
