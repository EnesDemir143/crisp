#!/bin/bash
# crisp module: uv
# Updates uv itself and all uv-installed tools

[[ -n "${CRISP_MOD_UV_LOADED:-}" ]] && return 0
readonly CRISP_MOD_UV_LOADED=1

crisp_uv_run() {
  if ! command -v uv &>/dev/null; then
    echo "    ⚠ uv not found, skipping"
    return
  fi

  echo "  → Uv self update..."
  uv self update 2>&1 | tail -1

  echo "  → Uv tools upgrade..."
  local tool_count
  tool_count=$(uv tool list 2>/dev/null | wc -l)
  uv tool upgrade --all 2>&1 | tail -5

  echo "    ✓ uv + $tool_count tools updated"
}
