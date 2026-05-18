#!/bin/bash
# crisp module: scan
# Deep scan: reads READMEs of all starred repos, detects install methods,
# checks local machine, updates STARRED_REPOS.md
# NOT in default run - call explicitly: crisp scan

crisp_scan_run() {
  echo "  → 🔍 Deep star scan starting..."
  echo "    This reads 130 repo READMEs via GitHub API and"
  echo "    detects local installations."
  echo "    (30-60 seconds)"
  echo

  # Check gh CLI
  if ! command -v gh &>/dev/null; then
    echo "  ┌────────────────────────────────────────────┐"
    echo "  │ ✗ gh CLI not found!                       │"
    echo "  │                                            │"
    echo "  │  To install:                             │"
    echo "  │    brew install gh                         │"
    echo "  │    gh auth login                           │"
    echo "  │                                            │"
    echo "  │  veya: https://cli.github.com/              │"
    echo "  └────────────────────────────────────────────┘"
    return 1
  fi

  # Check auth
  if ! gh auth status &>/dev/null; then
    echo "  ┌────────────────────────────────────────────┐"
    echo "  │ ✗ GitHub session not active!               │"
    echo "  │                                            │"
    echo "  │  To log in:                        │"
    echo "  │    gh auth login                           │"
    echo "  │                                            │"
    echo "  │  Browser opens, log in, token auto-saved │"
    echo "  │  Sonra tekrar: crisp scan                  │"
    echo "  └────────────────────────────────────────────┘"
    return 1
  fi

  echo "    ✓ gh CLI ready, session active"
  echo

  # Run the Python scanner
  python3 "$CRISP_DIR/scripts/scan_stars.py" 2>&1

  local exit_code=$?
  if [ $exit_code -eq 0 ]; then
    echo "  ┌────────────────────────────────────────────┐"
    echo "  │ ✓ Scan complete!                       │"
    echo "  │                                            │"
    echo "  │  Rapor: ~/Documents/crisp/STARRED_REPOS.md │"
    echo "  │                                            │"
    echo "  │  📌 = Installed on machine                     │"
    echo "  │  📦 = In README but not installed      │"
    echo "  │                                            │"
    echo "  │  When you clone a new repo:          │"
    echo "  │    crisp scan                              │"
    echo "  └────────────────────────────────────────────┘"
  fi

  return $exit_code
}
