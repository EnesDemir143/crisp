#!/usr/bin/env bash
# lib/core/base.sh — crisp foundation: OS detection, XDG paths, colors, icons
# Sourced by crisp main script. Guard against double-sourcing.
[[ -n "${CRISP_BASE_LOADED:-}" ]] && return 0
readonly CRISP_BASE_LOADED=1

# ─────────────────────────────────────────────────
# T6: OS Detection
# ─────────────────────────────────────────────────
detect_os() {
  case "$(uname -s)" in
    Darwin)          echo "macos" ;;
    Linux*)          echo "linux" ;;
    MINGW*|MSYS*)   echo "windows" ;;
    CYGWIN*)         echo "windows" ;;
    *)               echo "unknown" ;;
  esac
}

readonly CRISP_OS="$(detect_os)"

# ─────────────────────────────────────────────────
# T7: XDG-Compliant Paths
# ─────────────────────────────────────────────────
# Config: user preferences, crisp.conf
readonly CRISP_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/crisp"
# Data: inventory, backups, persistent state
readonly CRISP_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/crisp"
# Cache: temp files, downloaded metadata
readonly CRISP_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/crisp"

# CRISP_HOME: where crisp is installed (script directory)
# Supports override via env var for development/testing
if [[ -z "${CRISP_HOME:-}" ]]; then
  CRISP_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
readonly CRISP_HOME

# Derived paths (can be overridden in crisp.conf)
CRISP_CONF="${CRISP_CONF:-$CRISP_CONFIG_HOME/crisp.conf}"
CRISP_MODULES_DIR="${CRISP_MODULES_DIR:-$CRISP_HOME/lib/modules}"

# Ensure XDG directories exist
_ensure_xdg_dirs() {
  mkdir -p "$CRISP_CONFIG_HOME" "$CRISP_DATA_HOME" "$CRISP_CACHE_HOME" 2>/dev/null
}

# ─────────────────────────────────────────────────
# T9: Modular Color & Icon System
# ─────────────────────────────────────────────────

# Reset & formatting
readonly RST='\033[0m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly ITAL='\033[3m'
readonly UNDL='\033[4m'

# Standard colors
readonly RED='\033[0;31m'
readonly GRN='\033[0;32m'
readonly YEL='\033[0;33m'
readonly BLU='\033[0;34m'
readonly MAG='\033[0;35m'
readonly CYN='\033[0;36m'
readonly WHT='\033[0;37m'
readonly BLK='\033[0;30m'

# Bright/bold colors
readonly BRED='\033[1;31m'
readonly BGRN='\033[1;32m'
readonly BYEL='\033[1;33m'
readonly BBLU='\033[1;34m'
readonly BMAG='\033[1;35m'
readonly BCYN='\033[1;96m'
readonly BWHT='\033[1;37m'

# Background colors
readonly BG_RED='\033[41m'
readonly BG_GRN='\033[42m'
readonly BG_YEL='\033[43m'
readonly BG_BLU='\033[44m'
readonly BG_MAG='\033[45m'
readonly BG_CYN='\033[46m'
readonly BG_WHT='\033[47m'

# Unicode icons (readonly)
readonly ICO_OK="✓"
readonly ICO_ERR="✗"
readonly ICO_WARN="⚠"
readonly ICO_ARROW="▶"
readonly ICO_ARROW_UP="⬆"
readonly ICO_DOT_FILLED="●"
readonly ICO_DOT_EMPTY="○"
readonly ICO_DIAMOND="◆"
readonly ICO_BULLET="•"
readonly ICO_CHECK="✔"
readonly ICO_CROSS="✘"
readonly ICO_STAR="★"

# ─────────────────────────────────────────────────
# Utility functions
# ─────────────────────────────────────────────────
term_width() { tput cols 2>/dev/null || echo 80; }
term_height() { tput lines 2>/dev/null || echo 24; }

# Center a string within terminal width
# Usage: center_str "text" [width]
center_str() {
  local text="$1" w="${2:-$(term_width)}"
  local stripped; stripped="$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')"
  local pad=$(( (w - ${#stripped}) / 2 ))
  [[ $pad -lt 0 ]] && pad=0
  printf "%${pad}s%s" "" "$text"
}

# Horizontal divider line
# Usage: divider [char] [width]
divider() {
  local ch="${1:─}" w="${2:-$(term_width)}"
  printf "${ch}%.0s" $(seq 1 $((w - 4)))
}
