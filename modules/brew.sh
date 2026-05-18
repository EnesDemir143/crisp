#!/bin/bash
# crisp module: brew
# Runs brew update + brew upgrade

crisp_brew_run() {
  echo "  → Brew update..."
  brew update 2>&1 | tail -1
  echo "  → Brew upgrade..."
  brew upgrade 2>&1 | tail -3
  echo "    ✓ brew up to date"
}
