#!/usr/bin/env bash
# crisp module: radar
# Deprecation radar for local tracked repos — detects abandonment signals,
# suggests alternatives, and checks CI/CD health (Phase 04: T6-T8).

[[ -n "${CRISP_MOD_RADAR_LOADED:-}" ]] && return 0
readonly CRISP_MOD_RADAR_LOADED=1

# ─────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────

# Cross-platform ISO 8601 to epoch seconds
_crisp_iso_to_epoch() {
  local iso="$1"
  iso="${iso%%+*}"
  iso="${iso%Z}"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    date -j -f "%Y-%m-%dT%H:%M:%S" "$iso" +%s 2>/dev/null
  else
    date -d "${iso}" +%s 2>/dev/null
  fi
}

# Months between an epoch and now (30-day month approximation)
_crisp_months_since() {
  local epoch="$1" now
  now=$(date +%s)
  echo $(((now - epoch) / 2592000))
}

# Fetch from GitHub API — gh api with curl fallback
_crisp_gh_get() {
  local endpoint="$1" jq_expr="${2:-.}"
  local result

  if command -v gh &>/dev/null; then
    result=$(gh api "$endpoint" --jq "$jq_expr" 2>/dev/null) || return 1
    [[ -n "$result" ]] && printf '%s' "$result" && return 0
    return 1
  fi

  if command -v curl &>/dev/null; then
    result=$(curl -fsS --connect-timeout 10 "https://api.github.com/$endpoint" 2>/dev/null) || return 1
    if [[ -n "$result" ]]; then
      if command -v jq &>/dev/null; then
        printf '%s' "$result" | jq -r "$jq_expr" 2>/dev/null
      else
        printf '%s' "$result"
      fi
      return 0
    fi
  fi

  return 1
}

# Fetch full JSON response from GitHub API
_crisp_gh_get_json() {
  local endpoint="$1"

  if command -v gh &>/dev/null; then
    gh api "$endpoint" 2>/dev/null && return 0
  fi

  if command -v curl &>/dev/null; then
    curl -fsS --connect-timeout 10 "https://api.github.com/$endpoint" 2>/dev/null && return 0
  fi

  return 1
}

# Extract owner/repo from git remote URL
_crisp_parse_github_remote() {
  local url="$1" path repo

  # ssh: git@github.com:owner/repo.git
  if [[ "$url" == git@github.com:* ]]; then
    path="${url#git@github.com:}"
    path="${path%.git}"
    repo="${path##*/}"
    local owner="${path%/*}"
    [[ -n "$owner" && -n "$repo" ]] && echo "${owner}/${repo}" && return 0
  fi

  # https: https://github.com/owner/repo.git or http://github.com/owner/repo
  if [[ "$url" == https://github.com/* ]] || [[ "$url" == http://github.com/* ]]; then
    path="${url#http*://github.com/}"
    path="${path%.git}"
    repo="${path##*/}"
    local owner="${path%/*}"
    [[ -n "$owner" && -n "$repo" ]] && echo "${owner}/${repo}" && return 0
  fi

  return 1
}

# Simple grep-based JSON field extraction (no jq dependency)
_crisp_json_field() {
  local json="$1" field="$2"
  local raw
  raw=$(echo "$json" | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*[^,}]*" | head -1)
  # Strip field name and colon: remove everything up to and including the first ": "
  raw="${raw#*\": }"
  raw="${raw#*\":}"
  # Strip surrounding quotes if present
  raw="${raw#\"}"
  raw="${raw%\"}"
  echo "$raw"
}

# Simple grep-based JSON array field extraction
_crisp_json_array_field() {
  local json="$1" field="$2"
  # Matches "field": ["val1","val2",...]
  echo "$json" | sed -n "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p" | sed 's/"//g;s/,/ /g'
}

# Read configured repos from repos.conf
_crisp_radar_read_repos() {
  local conf="${CRISP_RADAR_REPOS_CONF:-${CRISP_CONFIG_HOME:-$HOME/.config/crisp}/repos.conf}"
  if [[ -f "$conf" ]]; then
    sed -n 's/^track:[[:space:]]*//p' "$conf" | while IFS= read -r repo; do
      [[ -n "$repo" ]] && printf '%s\n' "${repo/#\~/$HOME}"
    done
  fi
}

# ─────────────────────────────────────────────────
# T6: Abandonment detection for a single repo
# Returns: score|signal1,signal2,...
# ─────────────────────────────────────────────────
_crisp_radar_check_repo() {
  local owner_repo="$1"
  local score=0
  local signals=()
  local meta_json release_json ci_json

  # Fetch repo metadata (includes pushed_at, open_issues_count, language, topics, description)
  meta_json=$(_crisp_gh_get_json "repos/$owner_repo") || {
    echo "0|API error"
    return 0
  }

  local pushed_at open_issues language topics description stargazers created_at
  pushed_at=$(_crisp_json_field "$meta_json" "pushed_at")
  open_issues=$(_crisp_json_field "$meta_json" "open_issues_count")
  language=$(_crisp_json_field "$meta_json" "language")
  description=$(_crisp_json_field "$meta_json" "description")
  stargazers=$(_crisp_json_field "$meta_json" "stargazers_count")
  created_at=$(_crisp_json_field "$meta_json" "created_at")
  topics=$(_crisp_json_array_field "$meta_json" "topics")

  local pushed_epoch=0 pushed_months=0
  if [[ -n "$pushed_at" && "$pushed_at" != "null" ]]; then
    pushed_epoch=$(_crisp_iso_to_epoch "$pushed_at")
    pushed_months=$(_crisp_months_since "$pushed_epoch")
  fi

  # Signal 1: No commits in > 12 months (+40)
  if [[ "$pushed_months" -gt 12 ]]; then
    score=$((score + 40))
    signals+=("No commits in ${pushed_months} months")
  fi

  # Signal 2: No releases in > 12 months (+30)
  local latest_release_date=""
  release_json=$(_crisp_gh_get_json "repos/$owner_repo/releases?per_page=1") || true
  if [[ -n "$release_json" && "$release_json" != "[]" ]]; then
    latest_release_date=$(_crisp_json_field "$release_json" "published_at")
  fi

  local release_epoch=0 release_months=0
  local has_release=false
  if [[ -n "$latest_release_date" && "$latest_release_date" != "null" ]]; then
    has_release=true
    release_epoch=$(_crisp_iso_to_epoch "$latest_release_date")
    release_months=$(_crisp_months_since "$release_epoch")
  fi

  if $has_release && [[ "$release_months" -gt 12 ]]; then
    score=$((score + 30))
    signals+=("No releases in ${release_months} months")
  elif ! $has_release; then
    local repo_age_months=0
    if [[ -n "$created_at" && "$created_at" != "null" ]]; then
      local created_epoch
      created_epoch=$(_crisp_iso_to_epoch "$created_at")
      repo_age_months=$(_crisp_months_since "$created_epoch")
    fi
    if [[ "$repo_age_months" -gt 12 ]]; then
      score=$((score + 30))
      signals+=("No releases in ${repo_age_months} months")
    fi
  fi

  # Signal 3: Low issue closure rate (+20)
  local issue_count=0
  if [[ -n "$open_issues" && "$open_issues" != "null" ]]; then
    issue_count=$open_issues
  fi
  if [[ "$issue_count" -gt 3 ]] && [[ "$pushed_months" -gt 6 ]]; then
    score=$((score + 20))
    signals+=("Low issue closure rate")
  fi

  # Signal 4: No recent activity (+10) — catch-all for mildly stale repos
  if [[ "$pushed_months" -gt 3 && "$pushed_months" -le 12 ]] && [[ "$score" -eq 0 ]]; then
    score=$((score + 10))
    signals+=("No recent activity")
  fi

  # T8: CI/CD rot detection (+15)
  ci_json=$(_crisp_gh_get_json "repos/$owner_repo/actions/runs?per_page=1") 2>/dev/null || true
  if [[ -n "$ci_json" && "$ci_json" != "[]" && "$ci_json" != "null" ]]; then
    local last_ci_date raw
    raw=$(echo "$ci_json" | grep -o '"updated_at"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1)
    last_ci_date="${raw#*\": \"}"
    last_ci_date="${last_ci_date%\"}"
    if [[ -n "$last_ci_date" && "$last_ci_date" != "null" ]]; then
      local ci_epoch ci_months
      ci_epoch=$(_crisp_iso_to_epoch "$last_ci_date")
      ci_months=$(_crisp_months_since "$ci_epoch")
      if [[ "$ci_months" -gt 6 ]]; then
        score=$((score + 15))
        signals+=("CI inactive (${ci_months} months)")
      fi
    fi
  fi

  # Cap score at 100
  ((score > 100)) && score=100

  local signal_str
  if [[ ${#signals[@]} -eq 0 ]]; then
    signal_str="Active"
  else
    signal_str=$(printf '%s' "${signals[0]}")
    for ((i = 1; i < ${#signals[@]}; i++)); do
      signal_str+=", ${signals[i]}"
    done
  fi

  echo "${score}|${signal_str}|${language:-}|${topics:-}|${stargazers:-0}|${description:-}"
}

# ─────────────────────────────────────────────────
# T7: Alternative suggestions for abandoned repos
# ─────────────────────────────────────────────────
_crisp_radar_find_alternatives() {
  local owner_repo="$1" language="$2" topics="$3"
  local query_parts=()

  [[ -n "$language" && "$language" != "null" ]] && query_parts+=("language:${language}")

  # Use first topic if available
  local first_topic
  first_topic=$(echo "$topics" | awk '{print $1}')
  [[ -n "$first_topic" && "$first_topic" != "null" ]] && query_parts+=("topic:${first_topic}")

  # Fallback: search by repo name keywords
  if [[ ${#query_parts[@]} -eq 0 ]]; then
    local name_only="${owner_repo#*/}"
    query_parts+=("${name_only} in:name")
  fi

  local query
  query=$(printf ' %s' "${query_parts[@]}")
  query="${query# }"

  local search_results
  if command -v gh &>/dev/null; then
    search_results=$(gh search repos "$query" --sort=stars --limit=3 --json name,fullName,stargazersCount,updatedAt,description 2>/dev/null) || true
  elif command -v curl &>/dev/null; then
    local encoded_query
    encoded_query=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$query'))" 2>/dev/null || echo "$query")
    search_results=$(curl -fsS --connect-timeout 10 \
      "https://api.github.com/search/repositories?q=${encoded_query}&sort=stars&order=desc&per_page=3" 2>/dev/null) || true
  fi

  if [[ -z "$search_results" || "$search_results" == "[]" ]]; then
    return 1
  fi

  # Parse results — try jq first, fall back to grep
  if command -v jq &>/dev/null && echo "$search_results" | jq -e '.items' &>/dev/null 2>&1; then
    echo "$search_results" | jq -r '.items[] | "\(.full_name)|\(.stargazers_count)|\(.updated_at)|\(.description // "")"' 2>/dev/null
  elif echo "$search_results" | grep -q '"full_name"'; then
    # Crude grep-based extraction
    local entries=()
    while IFS= read -r line; do
      local fn stars updated desc
      fn=$(echo "$line" | grep -o '"full_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
      stars=$(echo "$line" | grep -o '"stargazers_count"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | sed 's/.*:[[:space:]]*//')
      updated=$(echo "$line" | grep -o '"updated_at"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
      desc=$(echo "$line" | grep -o '"description"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//')
      [[ -n "$fn" ]] && entries+=("${fn}|${stars:-0}|${updated:-}|${desc:-}")
    done < <(echo "$search_results" | tr '}' '\n')
    printf '%s\n' "${entries[@]}"
  fi
}

# ─────────────────────────────────────────────────
# Main orchestrator (T6+T7+T8)
# ─────────────────────────────────────────────────
_crisp_run_radar() {
  if ! command -v gh &>/dev/null && ! command -v curl &>/dev/null; then
    echo "  → radar requires gh or curl, skipping"
    return 0
  fi

  local repos=()
  while IFS= read -r repo; do
    [[ -n "$repo" ]] && repos+=("$repo")
  done < <(_crisp_radar_read_repos)

  if [[ "${#repos[@]}" -eq 0 ]]; then
    echo "  → No tracked repos configured"
    echo "    Add entries to ~/.config/crisp/repos.conf:"
    echo "    track: ~/path/to/repo"
    return 0
  fi

  echo
  echo -e "  ${BOLD}📡 Deprecation Radar${RST}"
  echo -e "  ${DIM}──────────────────────────────────────────────${RST}"

  # Collect results
  declare -a repo_names=()
  declare -a repo_scores=()
  declare -a repo_signals=()
  declare -a repo_languages=()
  declare -a repo_topics=()
  declare -a repo_stars=()
  declare -a repo_descriptions=()
  declare -a repo_owners=()

  local repo_path name remote origin
  for repo_path in "${repos[@]}"; do
    [[ -d "$repo_path/.git" ]] || continue

    remote=$(git -C "$repo_path" remote get-url origin 2>/dev/null) || continue
    origin=$(_crisp_parse_github_remote "$remote") || continue

    name=$(basename "$repo_path")
    repo_names+=("$name")
    repo_owners+=("$origin")

    # Check repo and parse results
    local result
    result=$(_crisp_radar_check_repo "$origin")
    repo_scores+=("$(echo "$result" | cut -d'|' -f1)")
    repo_signals+=("$(echo "$result" | cut -d'|' -f2)")
    repo_languages+=("$(echo "$result" | cut -d'|' -f3)")
    repo_topics+=("$(echo "$result" | cut -d'|' -f4)")
    repo_stars+=("$(echo "$result" | cut -d'|' -f5)")
    repo_descriptions+=("$(echo "$result" | cut -d'|' -f6-)")
  done

  local count="${#repo_names[@]}"
  if [[ "$count" -eq 0 ]]; then
    echo "  → No GitHub repos found among tracked repos"
    return 0
  fi

  # Display table header
  printf "  ${BOLD}%-20s %6s   %s${RST}\n" "repo" "score" "signals"
  echo -e "  ${DIM}──────────────────────────────────────────────${RST}"

  local i
  for ((i = 0; i < count; i++)); do
    local score="${repo_scores[$i]}"
    local s_color=""
    local s_icon=""

    if [[ "$score" -ge 70 ]]; then
      s_color="${RED}"
      s_icon="⚠ "
    elif [[ "$score" -ge 40 ]]; then
      s_color="${YEL}"
      s_icon="⚡ "
    else
      s_color="${GRN}"
      s_icon="✓ "
    fi

    printf "  ${s_color}%-20s %s%3d   %s${RST}\n" \
      "${repo_names[$i]:0:20}" \
      "$s_icon" \
      "$score" \
      "${repo_signals[$i]}"
  done

  echo -e "  ${DIM}──────────────────────────────────────────────${RST}"

  # T7: Show alternatives for abandoned repos (score > 40)
  local has_alternatives=false
  for ((i = 0; i < count; i++)); do
    if [[ "${repo_scores[$i]}" -gt 40 ]]; then
      has_alternatives=true
    fi
  done

  if $has_alternatives; then
    echo
    echo -e "  ${BOLD}${YEL}🔍 Alternatives for flagged repos${RST}"
    echo -e "  ${DIM}──────────────────────────────────────────────${RST}"

    for ((i = 0; i < count; i++)); do
      if [[ "${repo_scores[$i]}" -gt 40 ]]; then
        local lang="${repo_languages[$i]}"
        local topics="${repo_topics[$i]}"
        echo -e "  ${YEL}⚠ ${repo_names[$i]} appears abandoned →${RST}"

        local alts
        alts=$(_crisp_radar_find_alternatives "${repo_owners[$i]}" "$lang" "$topics") || true

        if [[ -z "$alts" ]]; then
          echo "    ${DIM}No alternatives found${RST}"
        else
          while IFS='|' read -r alt_name alt_stars alt_updated alt_desc; do
            [[ -z "$alt_name" ]] && continue
            [[ "$alt_name" == "${repo_owners[$i]}" ]] && continue
            local updated_short="${alt_updated:0:10}"
            printf "    ${GRN}→ %-30s${RST} ${DIM}★ %-5s  updated %s${RST}\n" \
              "$alt_name" "$alt_stars" "${updated_short:-unknown}"
          done <<<"$alts"
        fi
        echo
      fi
    done
  fi

  echo
  echo -e "  ${DIM}Checked ${count} repo(s). Score: 0=active, 100=abandoned.${RST}"
  echo
}

# Module entry point (for _run_module / crisp all)
crisp_radar_run() {
  _crisp_run_radar "$@"
}
