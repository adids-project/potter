ROOT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
COWRIE_DOCKER_COMPOSE := docker compose -p adids-honeypots -f "$(ROOT_DIR)/docker-compose.yml"
SHIPPER_ENV_FILE := $(ROOT_DIR)/.env.shipper
SHIPPER_CA_FILE := $(ROOT_DIR)/filebeat/certs/ca/ca.crt

.PHONY: cowrie-up
cowrie-up:
	@mkdir -p "$(ROOT_DIR)/cowrie/var/log/cowrie" "$(ROOT_DIR)/cowrie/var/lib/cowrie"
	@chmod 0777 "$(ROOT_DIR)/cowrie/var/log/cowrie" "$(ROOT_DIR)/cowrie/var/lib/cowrie"
	@$(COWRIE_DOCKER_COMPOSE) up -d

.PHONY: cowrie-live-up
cowrie-live-up:
	@mkdir -p "$(ROOT_DIR)/cowrie/var/log/cowrie" "$(ROOT_DIR)/cowrie/var/lib/cowrie" "$(ROOT_DIR)/data/logs/zeek/live/cowrie/current"
	@chmod 0777 "$(ROOT_DIR)/cowrie/var/log/cowrie" "$(ROOT_DIR)/cowrie/var/lib/cowrie" "$(ROOT_DIR)/data/logs/zeek/live/cowrie/current"
	@$(COWRIE_DOCKER_COMPOSE) up -d cowrie zeek-cowrie-live

.PHONY: shipper-env-check
shipper-env-check:
	@if [ ! -f "$(SHIPPER_ENV_FILE)" ]; then \
		echo "Missing $(SHIPPER_ENV_FILE). Copy .env.shipper.example first." >&2; \
		exit 1; \
	fi
	@if [ ! -f "$(SHIPPER_CA_FILE)" ]; then \
		echo "Missing $(SHIPPER_CA_FILE). Copy the adids-elk CA certificate first." >&2; \
		exit 1; \
	fi

.PHONY: cowrie-live-shipper-up
cowrie-live-shipper-up: shipper-env-check
	@mkdir -p "$(ROOT_DIR)/cowrie/var/log/cowrie" "$(ROOT_DIR)/cowrie/var/lib/cowrie" "$(ROOT_DIR)/data/logs/zeek/live/cowrie/current"
	@chmod 0777 "$(ROOT_DIR)/cowrie/var/log/cowrie" "$(ROOT_DIR)/cowrie/var/lib/cowrie" "$(ROOT_DIR)/data/logs/zeek/live/cowrie/current"
	@$(COWRIE_DOCKER_COMPOSE) --env-file "$(SHIPPER_ENV_FILE)" up -d cowrie zeek-cowrie-live filebeat-cowrie-live-shipper

.PHONY: cowrie-down
cowrie-down:
	@$(COWRIE_DOCKER_COMPOSE) down

.PHONY: cowrie-ps
cowrie-ps:
	@$(COWRIE_DOCKER_COMPOSE) ps
