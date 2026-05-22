ROOT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
COWRIE_DOCKER_COMPOSE := docker compose -p adids-honeypots -f "$(ROOT_DIR)/docker-compose.yml"
SENSOR_HOST_GUARD_SCRIPT := $(ROOT_DIR)/scripts/sensor_host_guard.sh
ENSURE_SSHD_PULL_PORT_SCRIPT := $(ROOT_DIR)/scripts/ensure_sshd_pull_port.sh
COWRIE_PUBLIC_PORT ?= 22
POTTER_PULL_SSHD_PORT ?= 443
POTTER_MANAGE_SSHD ?= 1
export COWRIE_PUBLIC_PORT
export POTTER_PULL_SSHD_PORT
export POTTER_MANAGE_SSHD

.PHONY: sensor-host-init
sensor-host-init:
	@/bin/sh $(SENSOR_HOST_GUARD_SCRIPT) init

.PHONY: check-sensor-host
check-sensor-host:
	@/bin/sh $(SENSOR_HOST_GUARD_SCRIPT) check

.PHONY: ensure-sshd-pull-port
ensure-sshd-pull-port: check-sensor-host
	@/bin/sh $(ENSURE_SSHD_PULL_PORT_SCRIPT)

.PHONY: up
up: ensure-sshd-pull-port
	@printf '%s\n' "potter-up: 実行用ディレクトリを準備します"
	@mkdir -p "$(ROOT_DIR)/cowrie/var/log/cowrie" "$(ROOT_DIR)/cowrie/var/lib/cowrie" "$(ROOT_DIR)/data/logs/zeek/live/cowrie/current"
	@chmod 0777 "$(ROOT_DIR)/cowrie/var/log/cowrie" "$(ROOT_DIR)/cowrie/var/lib/cowrie" "$(ROOT_DIR)/data/logs/zeek/live/cowrie/current"
	@printf '%s\n' "potter-up: host port $(COWRIE_PUBLIC_PORT) で Cowrie と Zeek live capture を起動します"
	@$(COWRIE_DOCKER_COMPOSE) up -d cowrie zeek-cowrie-live
	@printf '%s\n' "potter-up: サービスを起動しました。状態確認は 'make ps' を使ってください"

.PHONY: down
down:
	@$(COWRIE_DOCKER_COMPOSE) down

.PHONY: ps
ps:
	@$(COWRIE_DOCKER_COMPOSE) ps
