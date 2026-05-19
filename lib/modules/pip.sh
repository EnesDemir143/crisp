#!/bin/bash
# crisp module: pip
# Upgrades pip itself and outdated user packages

[[ -n "${CRISP_MOD_PIP_LOADED:-}" ]] && return 0
readonly CRISP_MOD_PIP_LOADED=1

crisp_pip_run() {
  echo "  → Pip upgrade..."
  pip3 install --upgrade pip -q 2>/dev/null || true

  echo "  → Pip packages..."
  local outdated
  outdated=$(pip3 list --outdated --format=columns 2>/dev/null | tail -n +3)

  if [ -z "$outdated" ]; then
    echo "    ✓ All pip packages up to date"
  else
    echo "$outdated" | while IFS= read -r line; do
      local pkg cur latest
      pkg=$(echo "$line" | awk '{print $1}')
      cur=$(echo "$line" | awk '{print $2}')
      latest=$(echo "$line" | awk '{print $3}')
      [ -z "$pkg" ] && continue
      echo "    ⬆  ${pkg}: ${cur} → ${latest}"
      pip3 install --upgrade "$pkg" -q 2>/dev/null || true
    done
    echo "    ✓ Pip packages updated"
  fi
}
