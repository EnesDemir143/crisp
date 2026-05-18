#!/usr/bin/env bash
# crisp module: repos
# Fast-forward update for local Git repositories only.

[[ -n "${CRISP_MOD_REPOS_LOADED:-}" ]] && return 0
readonly CRISP_MOD_REPOS_LOADED=1

CRISP_REPOS_CONF="${CRISP_REPOS_CONF:-${CRISP_CONFIG_HOME:-$HOME/.config/crisp}/repos.conf}"
CRISP_REPO_CACHE="${CRISP_REPO_CACHE:-${CRISP_CACHE_HOME:-$HOME/.cache/crisp}/local_repos}"

crisp_repos_scan_local() {
  mkdir -p "$(dirname "$CRISP_REPO_CACHE")"

  # One comprehensive scan of local git repos. crisp only works from
  # repositories present on this machine; it does not fetch any account-level
  # GitHub lists.
  find "${CRISP_REPOS_SCAN_ROOT:-$HOME}" -maxdepth "${CRISP_REPOS_SCAN_DEPTH:-6}" -type d -name ".git" \
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
    2>/dev/null | while IFS= read -r d; do
      dirname "$d"
    done | sort -u > "$CRISP_REPO_CACHE"
}

crisp_repos_list_configured() {
  if [[ -f "$CRISP_REPOS_CONF" ]]; then
    sed -n 's/^track:[[:space:]]*//p' "$CRISP_REPOS_CONF" | while IFS= read -r repo; do
      [[ -n "$repo" ]] && printf '%s\n' "${repo/#\~/$HOME}"
    done
    return 0
  fi

  return 0
}

crisp_repos_update_one() {
  local repo="$1"
  [[ -d "$repo/.git" ]] || return 2

  local branch status upstream output
  branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null) || {
    echo "      ⚠ detached HEAD, skipped"
    return 3
  }

  status=$(git -C "$repo" status --porcelain 2>/dev/null)
  if [[ -n "$status" ]]; then
    echo "      ⚠ dirty working tree, skipped"
    return 3
  fi

  upstream=$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || {
    echo "      ⚠ no upstream for ${branch}, skipped"
    return 3
  }

  output=$(git -C "$repo" pull --ff-only 2>&1)
  if grep -q "Already up to date" <<< "$output"; then
    echo "      ✓ up to date (${upstream})"
    return 0
  fi

  if grep -q "Fast-forward\|Updating" <<< "$output"; then
    local summary
    summary=$(head -3 <<< "$output" | tr '\n' ' ')
    echo "      ⬆  ${summary:0:100}"
    return 1
  fi

  local err_line
  err_line=$(head -1 <<< "$output")
  echo "      ⚠  ${err_line:0:80}"
  return 4
}

crisp_repos_run() {
  if ! command -v git &>/dev/null; then
    echo "  → git not found, skipping repos"
    return 0
  fi

  local repos=()
  while IFS= read -r repo; do
    [[ -n "$repo" ]] && repos+=("$repo")
  done < <(crisp_repos_list_configured)

  if [[ "${#repos[@]}" -eq 0 ]]; then
    echo "  → No tracked repos configured"
    echo "    Add entries to ${CRISP_REPOS_CONF/#$HOME/~}:"
    echo "    track: ~/path/to/repo"
    return 0
  fi

  echo "  → ${#repos[@]} tracked repos configured"

  local updated=0 current=0 skipped=0 failed=0 result repo name
  for repo in "${repos[@]}"; do
    name="${repo/#$HOME/~}"
    echo "    📂 ${name}"
    crisp_repos_update_one "$repo"
    result=$?
    case "$result" in
      0) current=$((current + 1)) ;;
      1) updated=$((updated + 1)) ;;
      2|3) skipped=$((skipped + 1)) ;;
      *) failed=$((failed + 1)) ;;
    esac
  done

  echo "    ✓ ${updated} repos updated, ${current} already up to date, ${skipped} skipped, ${failed} failed"
}
