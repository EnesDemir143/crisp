#!/bin/bash
# crisp module: repos
# Git pull on all starred repos cloned locally

CRISP_STARRED_FILE="$CRISP_DIR/.starred_repos"
CRISP_REPO_CACHE="$CRISP_DIR/.local_repos"

crisp_repos_fetch_stars() {
  if ! command -v gh &>/dev/null; then
    return 1
  fi
  gh api user/starred --paginate --jq '.[].full_name' 2>/dev/null | sort -u > "$CRISP_STARRED_FILE"
}

crisp_repos_scan_local() {
  # One comprehensive scan of all local git repos with their remotes
  # Cached for 1 hour
  find ~ -maxdepth 6 -type d -name ".git" \
    -not -path "*/node_modules/*" \
    -not -path "*/.Trash/*" \
    -not -path "*/.cache/*" \
    -not -path "*/Library/*" \
    -not -path "*/Caskroom/*" \
    -not -path "*/__pycache__/*" \
    -not -path "*/site-packages/*" \
    -not -path "*/.codex/*" \
    -not -path "*/.unsloth/*" \
    -not -path "*/.oh-my-zsh/*" \
    -not -path "*/.vim/*" \
    -not -path "*/.hermes/hermes-agent/*" \
    -not -path "*/go/pkg/*" \
    2>/dev/null | while read d; do
    dir=$(dirname "$d")
    remote=$(cd "$dir" 2>/dev/null && git remote get-url origin 2>/dev/null)
    if [ -n "$remote" ]; then
      echo "$remote ||| $dir"
    fi
  done 2>/dev/null > "$CRISP_REPO_CACHE"
}

crisp_repos_run() {
  if ! command -v gh &>/dev/null; then
    echo "  → gh CLI not found, star scan skipped"
    return
  fi

  # Refresh stars if cache missing or older than 1 day
  if [ ! -f "$CRISP_STARRED_FILE" ] || [ -z "$(cat "$CRISP_STARRED_FILE" 2>/dev/null)" ]; then
    echo "  → Fetching star list from GitHub..."
    crisp_repos_fetch_stars
  fi

  if [ ! -f "$CRISP_STARRED_FILE" ] || [ ! -s "$CRISP_STARRED_FILE" ]; then
    echo "  → Star list empty, skipping"
    return
  fi

  # Scan local repos (cache valid for 1 hour)
  if [ ! -f "$CRISP_REPO_CACHE" ] || [ $(find "$CRISP_REPO_CACHE" -mmin +60 -print 2>/dev/null) ]; then
    echo "  → Scanning local repos..."
    crisp_repos_scan_local
  fi

  local star_count
  star_count=$(wc -l < "$CRISP_STARRED_FILE")
  echo "  → ${star_count} stars being scanned..."

  local updated=0 current=0 failed=0

  # For each star, check if we have it locally
  while IFS= read -r star; do
    [ -z "$star" ] && continue
    local star_lower
    star_lower=$(echo "$star" | tr '[:upper:]' '[:lower:]')
    local star_name
    star_name="${star_lower#*/}"

    # Search local repo cache for this star
    local match_path=""
    while IFS= read -r line; do
      local remote="${line% ||| *}"
      local local_path="${line#* ||| }"

      # Normalize remote
      local remote_norm=""
      if echo "$remote" | grep -q "github.com"; then
        if echo "$remote" | grep -q "://"; then
          remote_norm=$(echo "$remote" | sed 's/.*github.com\///i' | sed 's/\.git$//' | tr '[:upper:]' '[:lower:]')
        elif echo "$remote" | grep -q "git@"; then
          remote_norm=$(echo "$remote" | sed 's/.*github.com://i' | sed 's/\.git$//' | tr '[:upper:]' '[:lower:]')
        fi
      fi

      if [ "$remote_norm" = "$star_lower" ]; then
        match_path="$local_path"
        break
      fi

      # Also check if same repo name (fork match)
      local remote_name="${remote_norm#*/}"
      if [ "$remote_name" = "$star_name" ] && [ -n "$remote_name" ]; then
        match_path="$local_path"
        break
      fi
    done < "$CRISP_REPO_CACHE"

    [ -z "$match_path" ] && continue

    echo "    📂 ${star}"
    local output
    output=$(cd "$match_path" 2>/dev/null && git pull --ff-only 2>&1)

    if echo "$output" | grep -q "Already up to date"; then
      echo "      ✓ up to date"
      current=$((current + 1))
    elif echo "$output" | grep -q "Fast-forward\|Updating"; then
      local summary
      summary=$(echo "$output" | head -3 | tr '\n' ' ')
      echo "      ⬆  ${summary:0:100}"
      updated=$((updated + 1))
    else
      local err_line
      err_line=$(echo "$output" | head -1)
      echo "      ⚠  ${err_line:0:80}"
      failed=$((failed + 1))
    fi
  done < "$CRISP_STARRED_FILE"

  echo "    ✓ ${updated} repos updated, ${current} repos already up to date, ${failed} hata"
}
