#!/usr/bin/env bash
# crisp module: apt
# Runs apt update && apt upgrade (Linux only)

[[ -n "${CRISP_MOD_APT_LOADED:-}" ]] && return 0
readonly CRISP_MOD_APT_LOADED=1

# Linux only
[[ "${CRISP_OS:-unknown}" != "linux" ]] && return 0

crisp_apt_run() {
  if ! command -v apt &>/dev/null; then
    echo "    ⚠ apt not found, skipping"
    return 0
  fi

  echo "  → apt update..."
  sudo apt update -qq 2>&1 | tail -1

  echo "  → apt upgrade..."
  sudo apt upgrade -y -qq 2>&1 | tail -3

  echo "    ✓ apt packages updated"
}
