#!/bin/bash
# crisp module: hermes
# Updates Hermes Agent to latest version

[[ -n "${CRISP_MOD_HERMES_LOADED:-}" ]] && return 0
readonly CRISP_MOD_HERMES_LOADED=1

crisp_hermes_run() {
  if ! command -v hermes &>/dev/null; then
    echo "    ⚠ hermes not found, skipping"
    return
  fi

  echo "  → Hermes Agent update..."

  # Check current version
  local before
  before=$(hermes --version 2>/dev/null | head -1)

  hermes update 2>&1 | tail -3

  local after
  after=$(hermes --version 2>/dev/null | head -1)

  if [ "$before" = "$after" ]; then
    echo "    ✓ Hermes already up to date (${before})"
  else
    echo "    ✓ Hermes: ${before} → ${after}"
  fi
}
