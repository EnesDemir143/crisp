#!/bin/bash
# crisp module: pipx
# Updates pipx and all pipx-installed tools

crisp_pipx_run() {
  if ! command -v pipx &>/dev/null; then
    echo "    ⚠ pipx not found, skipping"
    return
  fi

  echo "  → Pipx upgrade all..."
  pipx upgrade-all 2>&1 | tail -5
  echo "    ✓ pipx tools updated"
}
