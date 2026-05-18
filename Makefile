# crisp — Makefile

.PHONY: test lint install-hooks uninstall-hooks install uninstall clean help

SHELL := /bin/bash
CRISP_HOME := $(shell pwd)
PREFIX ?= /usr/local/bin

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

test: ## Run all Bats tests
	@bats tests/

lint: ## Run ShellCheck on all .sh files
	@shellcheck -x lib/core/*.sh lib/modules/*.sh crisp

format: ## Run shfmt to format all .sh files
	@shfmt -w -i 2 -ci lib/core/*.sh lib/modules/*.sh crisp

install-hooks: ## Install pre-commit hooks
	@git config core.hooksPath .githooks
	@echo "✓ Pre-commit hooks installed"

uninstall-hooks: ## Remove pre-commit hooks
	@git config --unset core.hooksPath
	@echo "✓ Pre-commit hooks removed"

install: ## Install crisp to $(PREFIX)
	@ln -sf $(CRISP_HOME)/crisp $(PREFIX)/crisp
	@echo "✓ crisp installed to $(PREFIX)/crisp"

uninstall: ## Remove crisp from $(PREFIX)
	@rm -f $(PREFIX)/crisp
	@echo "✓ crisp removed from $(PREFIX)/crisp"

clean: ## Remove cache and temp files
	@rm -rf $(HOME)/.cache/crisp/*.tmp
	@echo "✓ Cache cleaned"

check: lint test ## Run all checks (lint + test)
