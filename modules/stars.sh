#!/bin/bash
# crisp module: stars
# Generates STARRED_REPOS.md from GitHub stars + local scan
# NOT in default CRISP_MODULES - call explicitly: crisp stars

crisp_stars_run() {
  echo "  → Preparing star report..."

  if ! command -v gh &>/dev/null; then
    echo "    ✗ gh CLI gerekli"
    return 1
  fi

  # Fetch fresh stars
  echo "    → Fetching star list from GitHub..."
  gh api user/starred --paginate --jq '.[].full_name' 2>/dev/null \
    > "$CRISP_DIR/.starred_repos"

  local count
  count=$(wc -l < "$CRISP_DIR/.starred_repos")
  echo "      ✓ ${count} star bulundu"

  # Run analysis
  echo "    → Local scan + report generation..."
  python3 "$CRISP_DIR/scripts/generate_report.py" 2>&1
}
