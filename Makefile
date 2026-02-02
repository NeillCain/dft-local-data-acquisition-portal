# =========================
# Developer Workflow Makefile (Xdebug listens on port 9000 - launch.json)
# =========================

SHELL := /bin/sh
.DEFAULT_GOAL := help

# ----- Config -----
PHP        ?= php
HOST       ?= 0.0.0.0
PORT       ?= 8000
DOCROOT    ?= public
FRONT_HOST ?= frontend.localtest.me
ADMIN_HOST ?= admin.localtest.me

# Xdebug
XDBG_MODE  ?= debug,develop
XDBG_PORT  ?= 9000
XDBG_HOST  ?= 127.0.0.1

# PHPUnit / Coverage
PHPUNIT        ?= ./bin/phpunit
PHPUNIT_FLAGS  ?= -d memory_limit=1G
COV_DIR        ?= var/coverage
COV_INDEX      := $(COV_DIR)/index.html
COV_PORT       ?= 8081
COV_PID        := /tmp/coverage-server.pid
COV_LOG        := /tmp/coverage-server.log

# Server command + files
PHP_SERVER_CMD = $(PHP) -S $(HOST):$(PORT) -t $(DOCROOT)
PHP_SERVER_LOG = /tmp/php-server.log
PHP_SERVER_PID = /tmp/php-server.pid
MSG_LOG        = /tmp/messenger.log

# ----- Hot reload (auto-restart PHP server when PHP/Twig/YAML change) -----
HOT_PATHS    ?= src templates config
HOT_FILE_CMD ?= find $(HOT_PATHS) -type f \( -name '*.php' -o -name '*.twig' -o -name '*.yaml' -o -name '*.yml' \) 2>/dev/null | sort -u

# ----- Helpers -----
define _start_server
	@mkdir -p /tmp
	@$(MAKE) --no-print-directory serve-stop >/dev/null 2>&1 || true
	@echo "Starting PHP server on :$(PORT) $(if $(1),with XDEBUG_MODE=$(1),without Xdebug)…"
	@nohup env $(if $(1),XDEBUG_MODE=$(1)) \
		$(PHP) \
		-d xdebug.client_host=$(XDBG_HOST) \
		-d xdebug.client_port=$(XDBG_PORT) \
		-d xdebug.start_with_request=yes \
		-S $(HOST):$(PORT) -t $(DOCROOT) >$(PHP_SERVER_LOG) 2>&1 & echo $$! > $(PHP_SERVER_PID)
	@sleep 0.3
	@$(MAKE) --no-print-directory serve-status
endef

# ----- Help -----
.PHONY: help
help: ## Show help
	@f="$(lastword $(MAKEFILE_LIST))"; \
	awk 'BEGIN {FS = ":.*?## "}; /^[a-zA-Z0-9_%. -]+:.*?## / {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}' "$$f"

# ----- Frontend (Encore) -----
.PHONY: watch build
watch: ## Encore watch
	yarn dev --watch

build: ## Build assets
	yarn build

# ----- PHP server (toggle Xdebug without restarting the container) -----
.PHONY: serve serve-debug serve-restart serve-stop serve-status debug-on debug-off debug-status
serve: ## Start server (no Xdebug)
	$(call _start_server,)

serve-debug: ## Start server with Xdebug (XDEBUG_MODE=$(XDBG_MODE))
	$(call _start_server,$(XDBG_MODE))

debug-on:  ## Alias: restart with Xdebug
	$(MAKE) serve-debug

debug-off: ## Alias: restart without Xdebug
	$(MAKE) serve

serve-restart: serve-stop serve ## Restart server (no Xdebug)

serve-stop: ## Stop server
	@if [ -f $(PHP_SERVER_PID) ]; then \
		PID=$$(cat $(PHP_SERVER_PID) 2>/dev/null || true); \
		if [ -n "$$PID" ] && kill -0 $$PID 2>/dev/null; then \
			echo "Stopping PHP server (PID $$PID)…"; \
			kill $$PID 2>/dev/null || true; \
			sleep 0.2; \
		fi; \
		rm -f $(PHP_SERVER_PID); \
	else \
		pkill -f '$(PHP_SERVER_CMD)' >/dev/null 2>&1 || true; \
	fi; \
	echo "PHP server stopped."

serve-status: ## Server status
	@if [ -f $(PHP_SERVER_PID) ]; then \
		PID=$$(cat $(PHP_SERVER_PID) 2>/dev/null || true); \
		if [ -n "$$PID" ] && kill -0 $$PID 2>/dev/null; then \
			echo "PHP server listening on http://$(FRONT_HOST):$(PORT)  (admin: http://$(ADMIN_HOST):$(PORT))"; \
			exit 0; \
		fi; \
	fi; \
	if pgrep -af '$(PHP_SERVER_CMD)' >/dev/null; then \
		echo "PHP server appears to be running (no pidfile). Logs: $(PHP_SERVER_LOG)"; \
		exit 0; \
	fi; \
	echo "PHP server not running. See $(PHP_SERVER_LOG)"; \
	exit 1

debug-status: ## Print effective Xdebug config (CLI + server env)
	@echo "---- php -i (CLI) ----"; \
	php -i | grep -E 'xdebug.client_(host|port)|xdebug.mode|start_with_request'
	@echo "---- server env ----"; \
	if [ -f $(PHP_SERVER_PID) ]; then tr '\0' '\n' </proc/$$(cat $(PHP_SERVER_PID))/environ | grep -E 'XDEBUG_MODE|PHP_INI|XDEBUG'; else echo "(no pid)"; fi

hot: ## Watch $(HOT_PATHS); restart server (no Xdebug) on change
	@command -v entr >/dev/null || { echo "entr not installed. Run: make install-entr"; exit 2; }
	@echo "Hot reload active (no Xdebug). Watching: $(HOT_PATHS)"
	@$(HOT_FILE_CMD) | entr -r sh -c '$(MAKE) --no-print-directory serve'

hot-debug: ## Watch $(HOT_PATHS); restart server with Xdebug on change
	@command -v entr >/dev/null || { echo "entr not installed. Run: make install-entr"; exit 2; }
	@echo "Hot reload active (Xdebug). Watching: $(HOT_PATHS)"
	@$(HOT_FILE_CMD) | entr -r sh -c '$(MAKE) --no-print-directory serve-debug'

install-entr: ## Install 'entr' for hot reload (Debian/Ubuntu images)
	@sudo apt-get update && sudo apt-get install -y entr

# ----- PHPUnit -----
.PHONY: test test-verbose test-debug
test: ## Run PHPUnit fast (Xdebug off)
	XDEBUG_MODE=off $(PHP) $(PHPUNIT_FLAGS) $(PHPUNIT)

test-verbose: ## PHPUnit verbose
	XDEBUG_MODE=off $(PHP) $(PHPUNIT_FLAGS) $(PHPUNIT) -v

test-debug: ## PHPUnit with Xdebug (breakpoints in tests)
	XDEBUG_MODE=$(XDBG_MODE) $(PHP) -d xdebug.client_host=$(XDBG_HOST) -d xdebug.client_port=$(XDBG_PORT) $(PHPUNIT_FLAGS) $(PHPUNIT) -v

# ----- Coverage (HTML + text) -----
.PHONY: coverage coverage-open coverage-serve coverage-stop coverage-clean
coverage: ## Generate HTML coverage (uses Xdebug coverage mode)
	@mkdir -p $(COV_DIR)
	XDEBUG_MODE=coverage $(PHP) -d xdebug.mode=coverage $(PHPUNIT_FLAGS) $(PHPUNIT) --coverage-html $(COV_DIR) --coverage-text

coverage-open: ## Print path to coverage report
	@test -f "$(COV_INDEX)" || { echo "No coverage report. Run: make coverage"; exit 2; }
	@echo "Coverage report: file://$(COV_INDEX)"

coverage-serve: ## Serve coverage at http://localhost:$(COV_PORT)
	@test -f "$(COV_INDEX)" || { echo "No coverage report. Run: make coverage"; exit 2; }
	@$(MAKE) --no-print-directory coverage-stop >/dev/null 2>&1 || true
	@nohup $(PHP) -S 0.0.0.0:$(COV_PORT) -t $(COV_DIR) >$(COV_LOG) 2>&1 & echo $$! > $(COV_PID)
	@echo "Serving coverage -> http://localhost:$(COV_PORT)  (logs: $(COV_LOG))"

coverage-stop: ## Stop coverage server
	@if [ -f $(COV_PID) ]; then \
		PID=$$(cat $(COV_PID)); \
		if [ -n "$$PID" ] && kill -0 $$PID 2>/dev/null; then kill $$PID 2>/dev/null || true; fi; \
		rm -f $(COV_PID); \
	fi; \
	echo "Coverage server stopped."

coverage-clean: ## Remove generated coverage
	rm -rf $(COV_DIR)

# ----- Messenger worker (optional) -----
.PHONY: consume consume-stop
consume: ## Start Messenger worker
	nohup $(PHP) bin/console messenger:consume async async_notify async_ldap -vv --time-limit=0 >$(MSG_LOG) 2>&1 & \
	&& echo "Messenger worker started. Logs: $(MSG_LOG)"

consume-stop: ## Stop Messenger worker
	@pkill -f 'bin/console messenger:consume' >/dev/null 2>&1 || true
	@echo "Messenger worker stopped."

# ----- One-off CLI (with/without Xdebug) -----
.PHONY: cli cli-debug
cli: ## Run CLI (make cli CMD="bin/console cache:clear -n")
	@sh -lc '$(PHP) $(CMD)'

cli-debug: ## Run CLI with Xdebug (make cli-debug CMD="bin/console app:screenshots --protocol=http --no-build -vvv")
	@sh -lc 'XDEBUG_MODE=$(XDBG_MODE) $(PHP) -d xdebug.client_host=$(XDBG_HOST) -d xdebug.client_port=$(XDBG_PORT) -d xdebug.start_with_request=yes $(CMD)'

# ----- Screenshots helpers -----
.PHONY: screenshots screenshots-http screenshots-compare
screenshots: ## Generate screenshots (https)
	APP_ENV=prod APP_DEBUG=0 $(PHP) bin/console app:screenshots --protocol=https

screenshots-http: ## Generate screenshots (http for local :8000)
	APP_ENV=prod APP_DEBUG=0 $(PHP) bin/console app:screenshots --protocol=http --no-build

# Usage: make screenshots-compare OLD=path/to/old NEW=path/to/new
screenshots-compare: ## Compare two screenshot runs (ImageMagick)
	@test -n "$(OLD)" && test -n "$(NEW)" || (echo "Usage: make screenshots-compare OLD=… NEW=…"; exit 2)
	bash screenshots/compare.sh "$(OLD)" "$(NEW)"

# ----- Utilities -----
.PHONY: logs doctor cc dump-autoload
logs: ## Tail server and messenger logs
	@touch $(PHP_SERVER_LOG) $(MSG_LOG)
	tail -f $(PHP_SERVER_LOG) $(MSG_LOG)

doctor: ## Quick health check
	@echo "== Port $(PORT) ==" && (ss -lnt 2>/dev/null | grep -E ':$(PORT)\b' || echo "no listener")
	@echo "== PHP server ==" && (pgrep -af '$(PHP_SERVER_CMD)' || echo "not running")
	@echo "== Asset check ==" && (test -f public/build/app.css && echo "public/build/app.css OK" || echo "missing (run: make build)")
	@echo "== HTTP probe ==" && (curl -sSf -H "Host: $(FRONT_HOST)" http://127.0.0.1:$(PORT)/ >/dev/null && echo "200 OK" || echo "probe failed")

cc: ## Symfony cache:clear
	$(PHP) bin/console cache:clear

dump-autoload: ## Optimise Composer autoload
	composer dump-autoload -o
