#!/bin/bash
# crisp module: npm
# Updates npm itself + global npm packages

[[ -n "${CRISP_MOD_NPM_LOADED:-}" ]] && return 0
readonly CRISP_MOD_NPM_LOADED=1


crisp_npm_run() {
  echo "  → Npm self-update..."
  npm install -g npm 2>&1 | tail -1 || true

  echo "  → Npm global packages..."

  local npm_cmd="npm"
  # Check if we need sudo for global npm
  if npm config get prefix 2>/dev/null | grep -q "/usr/local"; then
    npm_cmd="sudo npm"
  fi

  local outdated
  outdated=$($npm_cmd outdated -g 2>/dev/null | tail -n +2 | awk '{print $1, $4, $5}' 2>/dev/null)

  if [ -z "$outdated" ]; then
    echo "    ✓ All global npm packages up to date"
    $npm_cmd update -g 2>&1 | tail -1
  else
    echo "$outdated" | while read -r pkg cur latest; do
      [ -z "$pkg" ] && continue
      echo "    ⬆  ${pkg}: ${cur} → ${latest}"
    done
    $npm_cmd update -g 2>&1 | tail -3
    echo "    ✓ Global npm packages updated"
  fi
}
