#!/bin/bash
# crisp module: brew
# Runs brew update + brew upgrade

[[ -n "${CRISP_MOD_BREW_LOADED:-}" ]] && return 0
readonly CRISP_MOD_BREW_LOADED=1
# macOS only
[[ "${CRISP_OS:-unknown}" != "macos" ]] && return 0



crisp_brew_run() {
  echo "  → Brew update..."
  brew update 2>&1 | tail -1
  echo "  → Brew upgrade..."
  brew upgrade 2>&1 | tail -3
  echo "    ✓ brew up to date"
}
