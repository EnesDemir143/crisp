#!/usr/bin/env bash
# crisp installer — cross-platform one-liner
# Usage: curl -fsSL https://raw.githubusercontent.com/enesdemir/crisp/main/install.sh | bash
set -euo pipefail

BOLD='\033[1m'
CYN='\033[0;36m'
GRN='\033[0;32m'
YEL='\033[0;33m'
RED='\033[0;31m'
DIM='\033[2m'
RST='\033[0m'

status_ok() { echo -e "  ${GRN}✓${RST} $1"; }
status_warn() { echo -e "  ${YEL}⚠${RST} $1"; }
status_err() { echo -e "  ${RED}✗${RST} $1"; }
status_info() { echo -e "  ${CYN}→${RST} $1"; }

# ——————————————————————————————————————————
# Bash version check (bash 5.0+ required)
# ——————————————————————————————————————————
if [[ "${BASH_VERSINFO[0]}" -lt 5 ]]; then
  echo -e "${RED}${BOLD}crisp requires bash 5.0+${RST}"
  echo "  Current: $BASH_VERSION"
  echo "  macOS:  brew install bash && exec bash"
  echo "  Linux:  apt install bash (Debian/Ubuntu) or pacman -S bash (Arch)"
  exit 1
fi

# ——————————————————————————————————————————
# OS detection
# ——————————————————————————————————————————
detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux*) echo "linux" ;;
    MINGW* | MSYS*) echo "windows" ;;
    CYGWIN*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

OS="$(detect_os)"
echo -e "\n${BOLD}${CYN}  crisp installer${RST}\n"
echo -e "  OS: ${CYN}${OS}${RST}  Bash: ${CYN}${BASH_VERSION}${RST}\n"

# ——————————————————————————————————————————
# Determine install paths
# ——————————————————————————————————————————
CRISP_HOME="${CRISP_HOME:-$HOME/.local/share/crisp}"

case "$OS" in
  macos)
    BIN_DIR="${HOMEBREW_PREFIX:-$(brew --prefix 2>/dev/null || echo /opt/homebrew)}/bin"
    [[ -d "$BIN_DIR" ]] || BIN_DIR="/usr/local/bin"
    [[ -d "$BIN_DIR" ]] || {
      BIN_DIR="$HOME/.local/bin"
      mkdir -p "$BIN_DIR"
    }
    ;;
  linux | windows)
    if [[ -w "/usr/local/bin" ]]; then
      BIN_DIR="/usr/local/bin"
    else
      BIN_DIR="$HOME/.local/bin"
      mkdir -p "$BIN_DIR"
    fi
    ;;
  *)
    BIN_DIR="$HOME/.local/bin"
    mkdir -p "$BIN_DIR"
    ;;
esac

CRISP_BIN="$BIN_DIR/crisp"

# ——————————————————————————————————————————
# Clone / download crisp
# ——————————————————————————————————————————
CRISP_REPO="https://github.com/enesdemir/crisp.git"

if [[ -d "$CRISP_HOME/.git" ]]; then
  status_info "Updating existing install..."
  git -C "$CRISP_HOME" pull --ff-only origin main
else
  if command -v git &>/dev/null; then
    status_info "Cloning crisp into $CRISP_HOME..."
    git clone --depth 1 "$CRISP_REPO" "$CRISP_HOME"
  else
    status_info "Downloading crisp..."
    mkdir -p "$CRISP_HOME"
    curl -fsSL "https://github.com/enesdemir/crisp/archive/refs/heads/main.tar.gz" |
      tar xz --strip-components=1 -C "$CRISP_HOME"
  fi
fi
status_ok "Source in $CRISP_HOME"

# ——————————————————————————————————————————
# Symlink binary
# ——————————————————————————————————————————
if [[ -L "$CRISP_BIN" ]]; then
  rm -f "$CRISP_BIN"
fi
ln -sf "$CRISP_HOME/crisp" "$CRISP_BIN"
status_ok "Symlinked $CRISP_HOME/crisp → $CRISP_BIN"

# ——————————————————————————————————————————
# PATH check
# ——————————————————————————————————————————
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  status_warn "$BIN_DIR is not in PATH"
  echo -e "         Run ${CYN}crisp setup-path${RST} to add it, or add manually:"
  echo -e "         ${DIM}export PATH=\"$BIN_DIR:\$PATH\"${RST}"
fi

# ——————————————————————————————————————————
# Install completions
# ——————————————————————————————————————————
if [[ -d "$CRISP_HOME/completions" ]]; then
  case "$OS" in
    macos)
      if [[ -d "$(brew --prefix 2>/dev/null)/etc/bash_completion.d" ]]; then
        cp "$CRISP_HOME/completions/crisp.bash" "$(brew --prefix)/etc/bash_completion.d/crisp" 2>/dev/null || true
      fi
      ;;
    linux)
      mkdir -p "$HOME/.local/share/bash-completion/completions" 2>/dev/null || true
      cp "$CRISP_HOME/completions/crisp.bash" "$HOME/.local/share/bash-completion/completions/crisp" 2>/dev/null || true
      ;;
  esac
  status_ok "Completions installed"
fi

# ——————————————————————————————————————————
# Done
# ——————————————————————————————————————————
echo ""
echo -e "  ${BOLD}${GRN}✓ crisp installed!${RST}"
echo ""
echo -e "  ${BOLD}Usage:${RST}"
echo -e "    ${CYN}crisp${RST}             interactive menu"
echo -e "    ${CYN}crisp all${RST}         run all updates"
echo -e "    ${CYN}crisp --help${RST}      show help"
echo ""
