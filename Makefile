SHELL := /usr/bin/env bash

.DEFAULT_GOAL := help

ENV ?= dev
INVENTORY ?= inventories/$(ENV)/hosts.yml
LIMIT ?= zennook
PROFILES ?= dev-main andrea
OAUTH_PROVIDER ?= openai-codex

.PHONY: help backup purge install oauth-login smoke reinstall

help:
	@echo "OpenClaw Ops Targets"
	@echo ""
	@echo "  make backup                           Backup current OpenClaw + control-plane state"
	@echo "  make purge CONFIRM=1                 Purge deployed state and containers"
	@echo "  make install                          Install/reconcile enterprise + control-plane"
	@echo "  make oauth-login                      Run interactive OAuth login per profile"
	@echo "  make smoke                            Run post-install smoke checks"
	@echo "  make reinstall CONFIRM=1              backup + purge + install + smoke"
	@echo ""
	@echo "Variables:"
	@echo "  ENV=$(ENV) INVENTORY=$(INVENTORY) LIMIT=$(LIMIT)"
	@echo "  PROFILES='$(PROFILES)' OAUTH_PROVIDER=$(OAUTH_PROVIDER)"

backup:
	@ENV="$(ENV)" INVENTORY="$(INVENTORY)" LIMIT="$(LIMIT)" ./ops/backup.sh

purge:
	@if [[ "$(CONFIRM)" != "1" ]]; then echo "Use: make purge CONFIRM=1"; exit 1; fi
	@ENV="$(ENV)" INVENTORY="$(INVENTORY)" LIMIT="$(LIMIT)" ./ops/purge.sh --yes

install:
	@ENV="$(ENV)" INVENTORY="$(INVENTORY)" LIMIT="$(LIMIT)" ./ops/install.sh

oauth-login:
	@ENV="$(ENV)" INVENTORY="$(INVENTORY)" LIMIT="$(LIMIT)" PROFILES="$(PROFILES)" OAUTH_PROVIDER="$(OAUTH_PROVIDER)" ./ops/oauth-login.sh

smoke:
	@ENV="$(ENV)" INVENTORY="$(INVENTORY)" LIMIT="$(LIMIT)" ./ops/smoke.sh

reinstall:
	@if [[ "$(CONFIRM)" != "1" ]]; then echo "Use: make reinstall CONFIRM=1"; exit 1; fi
	@$(MAKE) backup ENV="$(ENV)" INVENTORY="$(INVENTORY)" LIMIT="$(LIMIT)"
	@$(MAKE) purge CONFIRM=1 ENV="$(ENV)" INVENTORY="$(INVENTORY)" LIMIT="$(LIMIT)"
	@$(MAKE) install ENV="$(ENV)" INVENTORY="$(INVENTORY)" LIMIT="$(LIMIT)"
	@$(MAKE) smoke ENV="$(ENV)" INVENTORY="$(INVENTORY)" LIMIT="$(LIMIT)"
