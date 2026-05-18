#!/usr/bin/env bash
# lib/core/ui.sh — crisp UI primitives: terminal control, key input, screen helpers
# Sourced by crisp main script. Guard against double-sourcing.
[[ -n "${CRISP_UI_LOADED:-}" ]] && return 0
readonly CRISP_UI_LOADED=1

# Requires base.sh to be sourced first (for colors, icons, term_width)
[[ -z "${CRISP_BASE_LOADED:-}" ]] && source "$(dirname "${BASH_SOURCE[0]}")/base.sh"

# ─────────────────────────────────────────────────
# Terminal control
# ─────────────────────────────────────────────────
hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }

# Use alternate screen buffer (like vim/less/htop)
# This gives a clean screen and restores previous content on exit
enter_alt_screen() { printf '\033[?1049h\033[H'; }
leave_alt_screen() { printf '\033[?1049l'; }

# Clear screen — works on both normal and alternate buffer
clear_screen() { printf '\033[2J\033[H'; }

# Fast redraw — move cursor to home without clearing (no flicker)
# Use this instead of clear_screen when content is being overwritten
cursor_home() { printf '\033[H'; }

# Clear from cursor to end of screen (for leftover lines)
clear_to_end() { printf '\033[J'; }

# ─────────────────────────────────────────────────
# T2: read_key() — Stable key input with vim bindings
# ─────────────────────────────────────────────────
# Returns a normalized key name. Handles:
#   Arrow keys (↑↓←→), Enter, ESC (alone vs sequence)
#   Vim: j/k/h/l, g (top), q (quit), v (version), 1-9 (quick select)
#
# Uses read -t 0.5 for ESC sequence detection (bash 5.0+ required).
# Isolated ESC (no sequence follows within 500ms) → "ESC"
# ESC + [ + A/B/C/D → arrow keys
# ESC + O + A/B/C/D → alternate arrow encoding (some terminals)
read_key() {
  local key
  IFS= read -r -s -n 1 key
  if [[ $? -ne 0 ]]; then echo "QUIT"; return; fi

  case "$key" in
    $'\x1b')
      # ESC detected — read next byte with 0.5s timeout
      local b1
      IFS= read -r -s -n 1 -t 0.5 b1
      if [[ -z "$b1" ]]; then echo "ESC"; return; fi
      case "$b1" in
        '['|O)
          # CSI or SS3 sequence — read the final byte
          local b2
          IFS= read -r -s -n 1 -t 0.5 b2
          case "$b2" in
            A) echo "UP"    ;;
            B) echo "DOWN"  ;;
            C) echo "RIGHT" ;;
            D) echo "LEFT"  ;;
            *) echo "ESC"   ;;
          esac ;;
        *) echo "ESC" ;;
      esac ;;
    '')  echo "ENTER" ;;
    q|Q) echo "QUIT"  ;;
    v|V) echo "VERSION" ;;
    h|H) echo "HELP"  ;;
    j|J) echo "DOWN"  ;;
    k|K) echo "UP"    ;;
    g|G) echo "TOP"   ;;
    l|L) echo "CLEAR" ;;
    [1-9]) echo "NUM:$key" ;;
    *) echo "CHAR:$key" ;;
  esac
}

# ─────────────────────────────────────────────────
# Auto-dismiss helper (T4)
# ─────────────────────────────────────────────────
# "Press any key" with 5-second auto-dismiss
# Usage: press_any_key [timeout_seconds]
press_any_key() {
  local timeout="${1:-5}"
  printf "\n  ${DIM}Press any key to return...${RST}"
  read -r -s -n 1 -t "$timeout"
}

# ─────────────────────────────────────────────────
# Screen drawing helpers
# ─────────────────────────────────────────────────

# Draw the ASCII art header (block characters, centered)
_draw_header() {
  local w
  w="$(term_width)"
  local title
  title=$(cat <<'ASCIITITLE'
   ██████╗██████╗ ██╗███████╗██████╗ 
  ██╔════╝██╔══██╗██║██╔════╝██╔══██╗
  ██║     ██████╔╝██║███████╗██████╔╝
  ██║     ██╔══██╗██║╚════██║██╔═══╝ 
  ╚██████╗██║  ██║██║███████║██║     
   ╚═════╝╚═╝  ╚═╝╚═╝╚══════╝╚═╝     
ASCIITITLE
  )
  while IFS= read -r line; do
    local pad=$(( (w - ${#line}) / 2 ))
    [[ $pad -lt 0 ]] && pad=0
    printf "%${pad}s" ""
    echo -e "${BCYN}${line}${RST}"
  done <<< "$title"
  # Tagline shifted 4 chars right from center
  local tagline="${DIM}${CRISP_TAGLINE}${RST}"
  local stripped_tag="${CRISP_TAGLINE}"
  local pad=$(( (w - ${#stripped_tag}) / 2 + 4 ))
  [[ $pad -lt 0 ]] && pad=0
  printf "%${pad}s" ""
  echo -e "${tagline}"
  echo
}

# Draw horizontal divider
_draw_divider() {
  local w
  w="$(term_width)"
  echo -e "  ${DIM}$(printf '─%.0s' $(seq 1 $((w - 4))))${RST}"
}

# Draw the bottom keybinding guide
_draw_footer() {
  local n="${1:-6}"
  local w
  w="$(term_width)"
  _draw_divider
  echo
  echo -e "  ${DIM}↑/↓ or j/k: navigate  ${ICO_BULLET}  Enter: select  ${ICO_BULLET}  1-${n}: quick select${RST}"
  echo -e "  ${DIM}v: version  ${ICO_BULLET}  h: help  ${ICO_BULLET}  q: quit${RST}"
  echo
  echo -e "  ${DIM}v${CRISP_VERSION}  ${ICO_BULLET}  ${CRISP_MODULES_DIR}${RST}"
}

# Draw menu items with selection highlight (Mole-style full redraw)
# Usage: _draw_menu_items selected_index
_draw_menu_items() {
  local sel="${1:-0}" n
  n="${#MENU_ITEMS[@]}"
  for ((i=0; i<n; i++)); do
    local num=$((i + 1))
    local title desc
    title="$(_get_menu_item "$i" title)"
    desc="$(_get_menu_item "$i" desc)"
    if [[ $i -eq $sel ]]; then
      echo -e "  ${BCYN}${ICO_ARROW} ${num}. ${title}${RST}"
      echo -e "     ${DIM}${desc}${RST}"
    else
      echo -e "  ${DIM}  ${num}.${RST} ${title}"
      echo -e "     ${DIM}${desc}${RST}"
    fi
    echo
  done
}

# ─────────────────────────────────────────────────
# Spinner (for long-running operations)
# ─────────────────────────────────────────────────
# Usage: spin "Loading..." command args...
# Runs command in background, shows spinner until done.
spin() {
  local msg="$1"; shift
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0

  "$@" &
  local pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${CYN}%s${RST} %s" "${frames[$i]}" "$msg"
    i=$(( (i + 1) % ${#frames[@]} ))
    sleep 0.1
  done

  wait "$pid"
  local exit_code=$?
  printf "\r\033[K"  # Clear spinner line
  return $exit_code
}

# Simple inline spinner (non-blocking, for use in loops)
# Call _spinner_start before loop, _spinner_tick in loop, _spinner_stop after
_spinner_start() {
  _SPINNER_I=0
  _SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
}

_spinner_tick() {
  printf "\r  ${CYN}%s${RST}" "${_SPINNER_FRAMES[$_SPINNER_I]}"
  _SPINNER_I=$(( (_SPINNER_I + 1) % ${#_SPINNER_FRAMES[@]} ))
}

_spinner_stop() {
  printf "\r\033[K"
}

# ─────────────────────────────────────────────────
# Format helpers
# ─────────────────────────────────────────────────

# Format a status line with icon
# Usage: status_ok "message" / status_warn "message" / status_err "message"
status_ok()   { echo -e "  ${GRN}${ICO_OK}${RST} $1"; }
status_warn() { echo -e "  ${YEL}${ICO_WARN}${RST} $1"; }
status_err()  { echo -e "  ${RED}${ICO_ERR}${RST} $1"; }
status_info() { echo -e "  ${CYN}${ICO_ARROW}${RST} $1"; }

# Format a key-value pair
# Usage: kv_label "Key" "Value"
kv_label() {
  echo -e "  ${BOLD}$1:${RST} $2"
}

# Format a section header
# Usage: section_header "Title"
section_header() {
  echo
  echo -e "  ${BOLD}$1${RST}"
}
