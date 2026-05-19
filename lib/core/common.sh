#!/usr/bin/env bash
# lib/core/common.sh — crisp module runner, shared utilities
# Sourced by crisp main script. Guard against double-sourcing.
[[ -n "${CRISP_COMMON_LOADED:-}" ]] && return 0
readonly CRISP_COMMON_LOADED=1

# Requires base.sh and ui.sh to be sourced first
[[ -z "${CRISP_BASE_LOADED:-}" ]] && source "$(dirname "${BASH_SOURCE[0]}")/base.sh"
[[ -z "${CRISP_UI_LOADED:-}" ]] && source "$(dirname "${BASH_SOURCE[0]}")/ui.sh"

# ─────────────────────────────────────────────────
# Module discovery & metadata
# ─────────────────────────────────────────────────

# Get the file path for a module
_module_path() {
  echo "$CRISP_MODULES_DIR/$1.sh"
}

# Get the count of enabled modules
_module_count() {
  echo "$CRISP_MODULES" | wc -w | tr -d ' '
}

# Get a module's human-readable description
_module_desc() {
  case "$1" in
    graphify) echo "Update graphify (knowledge graph + version)" ;;
    brew) echo "brew update + brew upgrade" ;;
    apt) echo "apt update && apt upgrade (Linux)" ;;
    pacman) echo "pacman -Syu (Arch Linux)" ;;
    pip) echo "pip self-upgrade + outdated packages" ;;
    pipx) echo "pipx upgrade-all" ;;
    npm) echo "npm self-update + global packages" ;;
    npx) echo "clear npx cache" ;;
    uv) echo "uv self update + uv tool upgrade --all" ;;
    hermes) echo "hermes agent update" ;;
    repos) echo "fast-forward pull tracked local repos" ;;
    code) echo "VS Code extensions update" ;;
    cargo) echo "cargo installed tools" ;;
    *) echo "custom module" ;;
  esac
}

# List all available modules (from lib/modules/*.sh)
_all_available_modules() {
  local modules=()
  for f in "$CRISP_MODULES_DIR"/*.sh; do
    [[ -f "$f" ]] && modules+=("$(basename "$f" .sh)")
  done
  echo "${modules[*]}"
}

# ─────────────────────────────────────────────────
# Module execution
# ─────────────────────────────────────────────────

# Run a single module with error isolation
# Usage: _run_module <name> [silent]
_run_module() {
  local name="$1" silent="${2:-false}"
  local path
  path="$(_module_path "$name")"

  if [[ ! -f "$path" ]]; then
    [[ "$silent" != "true" ]] && echo -e "  ${RED}${ICO_ERR} Module '${name}' not found${RST}"
    return 1
  fi

  # Dry-run mode — show what WOULD happen
  if [[ "${CRISP_DRY_RUN:-false}" == "true" ]]; then
    local desc
    desc="$(_module_desc "$name")"
    echo -e "  ${CYN}[${name}]${RST} ${DIM}→ would run: ${desc}${RST}"
    return 0
  fi

  # Source the module (guards prevent double-loading)
  source "$path"

  if declare -F "crisp_${name}_run" >/dev/null 2>&1; then
    [[ "$silent" != "true" ]] && echo -e "  ${CYN}[${name}]${RST}"
    if "crisp_${name}_run"; then
      [[ "$silent" != "true" ]] && echo -e "    ${GRN}${ICO_OK} done${RST}"
    else
      [[ "$silent" != "true" ]] && echo -e "    ${YEL}${ICO_WARN} completed with warnings${RST}"
    fi
    return 0
  else
    [[ "$silent" != "true" ]] && echo -e "  ${RED}${ICO_ERR} No run function for '${name}'${RST}"
    return 1
  fi
}

# Run all enabled modules sequentially
_run_all_modules() {
  clear_screen
  echo
  if [[ "${CRISP_DRY_RUN:-false}" == "true" ]]; then
    echo -e "  ${BOLD}${BYEL}crisp${RST} ${BOLD}— dry-run mode (no changes)${RST} ${DIM}$(date '+%H:%M')${RST}"
  else
    echo -e "  ${BOLD}${BCYN}crisp${RST} ${BOLD}— starting updates...${RST} ${DIM}$(date '+%H:%M')${RST}"
  fi
  _draw_divider
  echo

  local start_time
  start_time=$(date +%s)
  local ran=0 failed=0 total
  total="$(_module_count)"

  for m in $CRISP_MODULES; do
    if [[ -f "$(_module_path "$m")" ]]; then
      if _run_module "$m"; then
        ran=$((ran + 1))
      else failed=$((failed + 1)); fi
    fi
  done

  local elapsed=$(($(date +%s) - start_time))
  echo
  _draw_divider
  if [[ $failed -eq 0 ]]; then
    echo -e "  ${BG_GRN}${BLK} ${ICO_OK} crisp done ${RST} — ${ran}/${total} modules, ${elapsed}s"
  else
    echo -e "  ${BYEL}${BLK} ${ICO_WARN} crisp done ${RST} — ${ran} ok, ${failed} warning, ${elapsed}s"
  fi
  echo
}

# Quick update: only brew/pip/npm
_run_quick_update() {
  clear_screen
  echo
  echo -e "  ${BOLD}${BCYN}crisp quick${RST} ${BOLD}— core package update${RST}"
  echo
  for m in brew apt pip npm; do
    if echo "$CRISP_MODULES" | grep -qw "$m"; then _run_module "$m"; fi
  done
  echo
  echo -e "  ${GRN}${ICO_OK} Quick update done${RST}"
  echo
}
