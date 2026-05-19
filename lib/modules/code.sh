#!/bin/bash
# crisp module: code
# Updates VS Code extensions

[[ -n "${CRISP_MOD_CODE_LOADED:-}" ]] && return 0
readonly CRISP_MOD_CODE_LOADED=1

crisp_code_run() {
  if ! command -v code &>/dev/null; then
    echo "    ⚠ VS Code (code CLI) not found, skipping"
    return
  fi

  echo "  → VS Code extensions update..."
  local before after
  before=$(code --list-extensions 2>/dev/null | wc -l)

  code --update-extensions 2>&1 | tail -3

  echo "    ✓ VS Code extensions updated"
}
