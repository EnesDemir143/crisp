#!/bin/bash
# crisp module: npx
# Clears npx cache (removes stale packages)

[[ -n "${CRISP_MOD_NPX_LOADED:-}" ]] && return 0
readonly CRISP_MOD_NPX_LOADED=1

crisp_npx_run() {
  echo "  → NPx cache cleanup..."
  npx clear-cache 2>&1 | tail -1 || true
  echo "    ✓ NPx cache cleared"
}
