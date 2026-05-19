.PHONY: install test lint uninstall clean install-completions install-hooks version help

SHELL := /bin/bash

CRISP_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
CRISP_BIN := $(CRISP_DIR)/crisp

UNAME_S := $(shell uname -s)

# Binary targets — where to install the symlink
ifeq ($(UNAME_S),Darwin)
  BREW_PREFIX := $(shell brew --prefix 2>/dev/null || echo /opt/homebrew)
  ifneq ($(wildcard $(BREW_PREFIX)/bin),)
    CRISP_LINK := $(BREW_PREFIX)/bin/crisp
  else ifneq ($(wildcard /usr/local/bin),)
    CRISP_LINK := /usr/local/bin/crisp
  else
    CRISP_LINK := $(HOME)/.local/bin/crisp
  endif
else
  ifneq ($(wildcard /usr/local/bin),)
    CRISP_LINK := /usr/local/bin/crisp
  else
    CRISP_LINK := $(HOME)/.local/bin/crisp
  endif
endif

CRISP_CONFIG_HOME := $(HOME)/.config/crisp
CRISP_DATA_HOME := $(HOME)/.local/share/crisp
CRISP_CACHE_HOME := $(HOME)/.cache/crisp

# ─────────────────────────────────────────────────
# Install
# ─────────────────────────────────────────────────
install:
	@echo "=== crisp install ==="
	@echo "  Target: $(CRISP_LINK)"
	@mkdir -p "$(dir $(CRISP_LINK))"
	@ln -sf "$(CRISP_BIN)" "$(CRISP_LINK)"
	@echo "  + Symlinked $(CRISP_BIN) -> $(CRISP_LINK)"
	@mkdir -p "$(CRISP_CONFIG_HOME)" "$(CRISP_DATA_HOME)" "$(CRISP_CACHE_HOME)"
	@echo "  + Created config/data/cache dirs"
	@if ! grep -q "$(dir $(CRISP_LINK))" "$(HOME)/.bashrc" 2>/dev/null && \
	    ! grep -q "$(dir $(CRISP_LINK))" "$(HOME)/.zshrc" 2>/dev/null; then \
	  echo "  ! Add $(dir $(CRISP_LINK)) to your PATH if not already present."; \
	fi
	@echo "  Done. Run: crisp"

# ─────────────────────────────────────────────────
# Test
# ─────────────────────────────────────────────────
test:
	@echo "=== Running Bats tests ==="
	bats tests/

# ─────────────────────────────────────────────────
# Lint
# ─────────────────────────────────────────────────
lint:
	@echo "=== ShellCheck ==="
	shellcheck -x lib/core/*.sh lib/modules/*.sh crisp install.sh

# ─────────────────────────────────────────────────
# Uninstall
# ─────────────────────────────────────────────────
uninstall:
	@echo "=== crisp uninstall ==="
	@if [ -L "$(CRISP_LINK)" ]; then \
		rm -f "$(CRISP_LINK)"; \
		echo "  + Removed $(CRISP_LINK)"; \
	else \
		echo "  ! No symlink found at $(CRISP_LINK)"; \
	fi
	@echo "  Config/data/cache at:"
	@echo "    $(CRISP_CONFIG_HOME)"
	@echo "    $(CRISP_DATA_HOME)"
	@echo "    $(CRISP_CACHE_HOME)"
	@echo "  Remove manually if desired: rm -rf $(CRISP_CONFIG_HOME) $(CRISP_DATA_HOME) $(CRISP_CACHE_HOME)"

# ─────────────────────────────────────────────────
# Clean
# ─────────────────────────────────────────────────
clean:
	@echo "=== Clean ==="
	@rm -rf "$(CRISP_CACHE_HOME)" 2>/dev/null || true
	@echo "  + Removed $(CRISP_CACHE_HOME)"

# ─────────────────────────────────────────────────
# Shell completions
# ─────────────────────────────────────────────────
install-completions:
	@echo "=== Installing completions ==="
	@# bash
	@mkdir -p "$(HOME)/.local/share/bash-completion/completions" 2>/dev/null || true
	@cp completions/crisp.bash "$(HOME)/.local/share/bash-completion/completions/crisp" 2>/dev/null || \
		echo "  ! bash-completion dir not supported; source completions/crisp.bash manually"
	@# zsh
	@mkdir -p "$(HOME)/.zsh/completions" 2>/dev/null || \
		mkdir -p "/usr/local/share/zsh/site-functions" 2>/dev/null || true
	@cp completions/crisp.zsh "$(HOME)/.zsh/completions/_crisp" 2>/dev/null || \
		cp completions/crisp.zsh "/usr/local/share/zsh/site-functions/_crisp" 2>/dev/null || \
		echo "  ! Could not install zsh completions"
	@# fish
	@mkdir -p "$(HOME)/.config/fish/completions" 2>/dev/null || true
	@cp completions/crisp.fish "$(HOME)/.config/fish/completions/crisp.fish" 2>/dev/null || \
		echo "  ! Could not install fish completions"
	@echo "  + Completions installed"

# ─────────────────────────────────────────────────
# Git hooks
# ─────────────────────────────────────────────────
install-hooks:
	@echo "=== Installing git hooks ==="
	git config core.hooksPath .githooks
	@echo "  + hooksPath set to .githooks"

# ─────────────────────────────────────────────────
# Version
# ─────────────────────────────────────────────────
version:
	@VERSION=$$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"); \
	COMMIT=$$(git rev-parse --short HEAD 2>/dev/null || echo "unknown"); \
	echo "crisp $$VERSION ($$COMMIT)"

# ─────────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────────
help:
	@echo "crisp Makefile targets:"
	@echo "  make install           — symlink crisp to PATH + create config dirs"
	@echo "  make test              — run Bats tests"
	@echo "  make lint              — run ShellCheck"
	@echo "  make uninstall         — remove symlink"
	@echo "  make clean             — remove cache"
	@echo "  make install-completions — install bash/zsh/fish completions"
	@echo "  make install-hooks     — set core.hooksPath to .githooks"
	@echo "  make version           — show current git version"
	@echo "  make help              — show this message"
