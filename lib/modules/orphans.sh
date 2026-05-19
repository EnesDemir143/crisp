#!/usr/bin/env bash
# crisp module: orphans
# Intelligent orphan binary detection, version comparison, batch update, uninstall.

[[ -n "${CRISP_MOD_ORPHANS_LOADED:-}" ]] && return 0
readonly CRISP_MOD_ORPHANS_LOADED=1

# Source recipes for trusted update paths
source "${CRISP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/lib/core/recipes.sh"

CRISP_ORPHAN_INVENTORY="${CRISP_ORPHAN_INVENTORY:-$CRISP_DATA_HOME/inventory.json}"

# ─────────────────────────────────────────────────
# Internal helpers
# ─────────────────────────────────────────────────

_orphans_inventory_file() { echo "$CRISP_ORPHAN_INVENTORY"; }

_orphans_load_inventory() {
  local inv
  inv="$(_orphans_inventory_file)"
  if [[ -f "$inv" ]] && command -v python3 &>/dev/null; then
    python3 -c "import json; print(json.dumps(json.load(open('$inv')), indent=2))" 2>/dev/null || echo '{"binaries":{}}'
  else
    echo '{"binaries":{}}'
  fi
}

_orphans_save_inventory() {
  local json="$1" inv
  inv="$(_orphans_inventory_file)"
  mkdir -p "$(dirname "$inv")" 2>/dev/null
  echo "$json" >"$inv"
}

_orphans_get_entry() {
  local name="$1"
  _orphans_load_inventory | python3 -c "
import json,sys
d=json.load(sys.stdin)
e=d.get('binaries',{}).get('$name',{})
if e:
    print(json.dumps(e))
" 2>/dev/null
}

_orphans_set_entry() {
  local name="$1" version="$2" source="$3" method="$4" path="$5"
  local inv now
  inv="$(_orphans_inventory_file)"
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  mkdir -p "$(dirname "$inv")" 2>/dev/null
  python3 -c "
import json, sys
inv_path = '$inv'
try:
    with open(inv_path) as f:
        data = json.load(f)
except:
    data = {'binaries': {}}
data['binaries']['$name'] = {
    'version': '$version',
    'source': '$source',
    'detection_method': '$method',
    'installed_at': '$now',
    'binary_path': '$path'
}
with open(inv_path, 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
}

_orphans_remove_entry() {
  local name="$1" inv
  inv="$(_orphans_inventory_file)"
  if [[ -f "$inv" ]]; then
    python3 -c "
import json
inv_path = '$inv'
with open(inv_path) as f:
    data = json.load(f)
data.get('binaries', {}).pop('$name', None)
with open(inv_path, 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null
  fi
}

# Detect local version of a binary
_orphans_detect_version() {
  local binary="$1" out ver
  for flag in "--version" "version" "-v"; do
    out="$("$binary" "$flag" 2>/dev/null)" || continue
    ver="$(echo "$out" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
    [[ -n "$ver" ]] && {
      echo "$ver"
      return 0
    }
  done
  return 1
}

# Compare two semantic versions: returns "behind", "current", or "ahead"
_orphans_compare_versions() {
  local local_ver="$1" remote_ver="$2"
  [[ -z "$local_ver" || -z "$remote_ver" ]] && {
    echo "unknown"
    return
  }

  local a1 a2
  IFS='.' read -ra a1 <<<"${local_ver#v}"
  IFS='.' read -ra a2 <<<"${remote_ver#v}"

  for i in 0 1 2; do
    local n1="${a1[$i]:-0}" n2="${a2[$i]:-0}"
    ((n1 > n2)) && {
      echo "ahead"
      return
    }
    ((n1 < n2)) && {
      echo "behind"
      return
    }
  done
  echo "current"
}

# Check if binary is managed by a package manager
_orphans_is_package_managed() {
  local name="$1"

  command -v brew &>/dev/null && brew list --formula "$name" &>/dev/null 2>&1 && return 0
  command -v cargo &>/dev/null && cargo install --list 2>/dev/null | grep -q "^${name} " && return 0
  command -v npm &>/dev/null && npm list -g "$name" &>/dev/null 2>&1 && return 0
  if command -v pip3 &>/dev/null; then
    pip3 show "$name" &>/dev/null 2>&1 && return 0
  elif command -v pip &>/dev/null; then
    pip show "$name" &>/dev/null 2>&1 && return 0
  fi

  return 1
}

# Find GitHub repos referenced in a binary's strings
_orphans_find_github_repos() {
  local binary="$1"
  if ! command -v strings &>/dev/null; then
    return 1
  fi
  strings "$binary" 2>/dev/null | grep -Eo "github\.com/[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+" | sort -u | head -5
}

# Get latest release info from GitHub
_orphans_get_latest_release() {
  local repo="$1" result
  if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    result="$(gh api "repos/$repo/releases/latest" 2>/dev/null)" && {
      echo "$result"
      return 0
    }
  fi
  curl -sf "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null && return 0
  return 1
}

# Get scan directories based on OS
_orphans_scan_dirs() {
  case "$CRISP_OS" in
    macos)
      echo "/opt/homebrew/bin"
      echo "/usr/local/bin"
      echo "$HOME/.cargo/bin"
      echo "$HOME/.local/bin"
      echo "$HOME/bin"
      ;;
    linux)
      echo "/usr/local/bin"
      echo "$HOME/.cargo/bin"
      echo "$HOME/.local/bin"
      echo "$HOME/bin"
      echo "/home/linuxbrew/.linuxbrew/bin"
      ;;
    windows)
      echo "/usr/local/bin"
      echo "$HOME/.cargo/bin"
      echo "$HOME/.local/bin"
      echo "$HOME/bin"
      echo "/home/linuxbrew/.linuxbrew/bin"
      echo "/mingw64/bin"
      ;;
    *) return ;;
  esac
}

# ─────────────────────────────────────────────────
# T1: Full orphan scan
# ─────────────────────────────────────────────────
_crisp_scan_orphans() {
  echo "  → Scanning for orphan binaries..."
  echo

  local dirs=() dir
  while IFS= read -r dir; do
    [[ -d "$dir" ]] && dirs+=("$dir")
  done < <(_orphans_scan_dirs)

  local found=0 skipped=0 missing=0
  local binary name

  for dir in "${dirs[@]}"; do
    for binary in "$dir"/*; do
      [[ -f "$binary" && -x "$binary" ]] || continue
      name="$(basename "$binary")"

      if _orphans_is_package_managed "$name"; then
        skipped=$((skipped + 1))
        continue
      fi

      echo "    → ${name} (not package-managed)"

      local repos repo release tag ver
      while IFS= read -r repo; do
        [[ -z "$repo" ]] && continue
        release="$(_orphans_get_latest_release "$repo")" || continue
        tag="$(echo "$release" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tag_name',''))" 2>/dev/null)"
        [[ -z "$tag" ]] && continue

        ver="${tag#v}"
        local local_ver
        local_ver="$(_orphans_detect_version "$binary")"
        [[ -z "$local_ver" ]] && local_ver="$ver"

        _orphans_set_entry "$name" "$local_ver" "$repo" "strings" "$binary"
        echo "      ✓ recorded ${name} v${local_ver} (from ${repo})"
        found=$((found + 1))
        break
      done < <(_orphans_find_github_repos "$binary")

      if [[ -z "${repo:-}" ]]; then
        echo "      ⚠ no GitHub source found"
        missing=$((missing + 1))
      fi
    done
  done

  echo
  echo "    ✓ ${found} orphan(s) recorded, ${skipped} package-managed skipped, ${missing} unresolved"
}

# ─────────────────────────────────────────────────
# T2: Version comparison (check for updates)
# ─────────────────────────────────────────────────
_crisp_check_orphans() {
  local inv
  inv="$(_orphans_load_inventory)"

  local entries
  entries="$(echo "$inv" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for name, info in d.get('binaries',{}).items():
    print(f'{name}|{info.get(\"version\",\"?\")}|{info.get(\"source\",\"?\")}')
" 2>/dev/null)"

  if [[ -z "$entries" ]]; then
    echo "  → No orphan binaries tracked. Run 'crisp scan-orphans' first."
    return 0
  fi

  printf "  %-20s %-12s %-12s %-10s\n" "NAME" "LOCAL" "LATEST" "STATUS"
  echo "  $(printf '─%.0s' {1..60})"

  local name local_ver source
  while IFS='|' read -r name local_ver source; do
    [[ -z "$name" ]] && continue

    local latest_ver="" status="unknown"
    if [[ "$source" != "?" ]]; then
      local release tag
      release="$(_orphans_get_latest_release "$source")"
      if [[ -n "$release" ]]; then
        tag="$(echo "$release" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tag_name',''))" 2>/dev/null)"
        latest_ver="${tag#v}"
      fi
    fi

    if [[ -n "$latest_ver" ]]; then
      status="$(_orphans_compare_versions "$local_ver" "$latest_ver")"
    fi

    local icon
    case "$status" in
      behind) icon="⬇ " ;;
      current) icon="✓ " ;;
      ahead) icon="⬆ " ;;
      *)
        icon="? "
        latest_ver="?"
        ;;
    esac

    printf "  ${icon}%-18s %-12s %-12s %-10s\n" "$name" "$local_ver" "${latest_ver:-?}" "$status"
  done <<<"$entries"
}

# ─────────────────────────────────────────────────
# T3: Batch update behind binaries
# ─────────────────────────────────────────────────
_crisp_update_orphans() {
  local inv
  inv="$(_orphans_load_inventory)"

  # Collect behind entries
  local behind=() entries name local_ver source path
  entries="$(echo "$inv" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for name, info in d.get('binaries',{}).items():
    print(f'{name}|{info.get(\"version\",\"?\")}|{info.get(\"source\",\"?\")}|{info.get(\"binary_path\",\"?\")}')
" 2>/dev/null)"

  while IFS='|' read -r name local_ver source path; do
    [[ -z "$name" ]] && continue
    [[ "$source" == "?" ]] && continue

    local release tag latest_ver status
    release="$(_orphans_get_latest_release "$source")"
    [[ -z "$release" ]] && continue
    tag="$(echo "$release" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tag_name',''))" 2>/dev/null)"
    latest_ver="${tag#v}"
    status="$(_orphans_compare_versions "$local_ver" "$latest_ver")"

    [[ "$status" != "behind" ]] && continue
    behind+=("$name|$local_ver|$latest_ver|$source|$path")
  done <<<"$entries"

  if [[ "${#behind[@]}" -eq 0 ]]; then
    echo "  ✓ All tracked binaries are up to date."
    return 0
  fi

  echo "  → ${#behind[@]} binary(s) can be updated:"
  echo
  for entry in "${behind[@]}"; do
    IFS='|' read -r name local_ver latest_ver source path <<<"$entry"
    printf "    %-18s %s → %s\n" "$name" "$local_ver" "$latest_ver"
  done
  echo
  printf "  Proceed with updates? (y/n): "
  read -r confirm
  [[ "$confirm" =~ ^[yY] ]] || {
    echo "  ⚠ update cancelled"
    return 0
  }

  local updated=0 failed=0
  for entry in "${behind[@]}"; do
    IFS='|' read -r name local_ver latest_ver source path <<<"$entry"
    echo
    echo "  → Updating ${name} (${local_ver} → ${latest_ver})..."

    local success=false

    # Try trusted recipe first
    if _recipe_exists "$name"; then
      local recipe_cmd
      recipe_cmd="$(_recipe_update "$name")"
      echo "    (using trusted recipe: ${recipe_cmd})"
      if eval "$recipe_cmd" 2>&1; then
        success=true
      else
        echo "    ⚠ recipe update failed, trying GitHub release..."
      fi
    fi

    # Fall back to GitHub Releases download
    if [[ "$success" != "true" ]]; then
      local release_json dl_url
      release_json="$(_orphans_get_latest_release "$source")"
      if [[ -n "$release_json" ]]; then
        # Match platform-specific asset
        local arch_os
        case "$(uname -m)" in
          x86_64) arch_os=".*(x86_64|amd64|linux_amd64|darwin_amd64).*" ;;
          arm64 | aarch64) arch_os=".*(arm64|aarch64|darwin_arm64|linux_arm64).*" ;;
          *) arch_os=".*" ;;
        esac

        dl_url="$(echo "$release_json" | python3 -c "
import json,sys,re
d=json.load(sys.stdin)
pattern=r'${arch_os}'
for a in d.get('assets',[]):
    name=a.get('name','')
    url=a.get('browser_download_url','')
    if re.search(pattern, name, re.IGNORECASE):
        print(url)
        break
" 2>/dev/null)"

        if [[ -n "$dl_url" ]]; then
          echo "    → downloading from GitHub..."
          local tmpfile
          tmpfile="$(mktemp)"
          if curl -sfL "$dl_url" -o "$tmpfile" 2>&1; then
            if [[ "$dl_url" == *.tar.gz || "$dl_url" == *.tgz ]]; then
              tar -xzf "$tmpfile" -C "$(dirname "$path")" --strip-components=1 2>/dev/null && success=true
            elif [[ "$dl_url" == *.zip ]]; then
              unzip -o "$tmpfile" -d "$(dirname "$path")" 2>/dev/null && success=true
            else
              cp "$tmpfile" "$path" && chmod +x "$path" && success=true
            fi
            rm -f "$tmpfile"
          fi
        fi
      fi
    fi

    if [[ "$success" == "true" ]]; then
      local new_ver
      new_ver="$(_orphans_detect_version "$path")"
      [[ -z "$new_ver" ]] && new_ver="$latest_ver"
      _orphans_set_entry "$name" "$new_ver" "$source" "strings" "$path"
      echo "    ✓ ${name} updated to v${new_ver}"
      updated=$((updated + 1))
    else
      echo "    ⚠ failed to update ${name}"
      failed=$((failed + 1))
    fi
  done

  echo
  echo "    ✓ ${updated} updated, ${failed} failed"
}

# ─────────────────────────────────────────────────
# T5: List orphan binaries
# ─────────────────────────────────────────────────
_crisp_list_orphans() {
  local inv
  inv="$(_orphans_load_inventory)"

  local entries
  entries="$(echo "$inv" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for name, info in d.get('binaries',{}).items():
    print(f'{name}|{info.get(\"version\",\"?\")}|{info.get(\"source\",\"?\")}|{info.get(\"binary_path\",\"?\")}|{info.get(\"installed_at\",\"?\")}')
" 2>/dev/null)"

  if [[ -z "$entries" ]]; then
    echo "  → No orphan binaries tracked."
    return 0
  fi

  local count=0
  printf "  %-20s %-12s %-35s %-10s\n" "NAME" "VERSION" "SOURCE" "STATUS"
  echo "  $(printf '─%.0s' {1..80})"

  while IFS='|' read -r name version source path installed_at; do
    [[ -z "$name" ]] && continue
    count=$((count + 1))
    local status="ok"
    [[ ! -f "$path" ]] && status="missing"
    local icon="✓ "
    [[ "$status" == "missing" ]] && icon="⚠ "
    printf "  ${icon}%-18s %-12s %-35s %-10s\n" "$name" "$version" "$source" "$status"
  done <<<"$entries"

  echo
  echo "  ${count} binary(s) tracked in inventory"
}

# ─────────────────────────────────────────────────
# T5: Uninstall a tracked binary
# ─────────────────────────────────────────────────
_crisp_uninstall() {
  local target="$2"
  if [[ -z "$target" ]]; then
    echo "  Usage: crisp uninstall <name>"
    return 1
  fi

  local entry
  entry="$(_orphans_get_entry "$target")"
  if [[ -z "$entry" ]]; then
    echo "  ⚠ '${target}' not found in inventory"
    return 1
  fi

  local path
  path="$(echo "$entry" | python3 -c "import json,sys; print(json.load(sys.stdin).get('binary_path',''))" 2>/dev/null)"

  if [[ -n "$path" && -f "$path" ]]; then
    echo "  → Removing ${path}..."
    rm -f "$path" 2>/dev/null && echo "    ✓ binary removed" || echo "    ⚠ could not remove binary"
  fi

  _orphans_remove_entry "$target"
  echo "    ✓ '${target}' removed from inventory"
}

# ─────────────────────────────────────────────────
# T5: Orphans submenu (--prune)
# ─────────────────────────────────────────────────
_crisp_orphans_menu() {
  local sub="$1"

  case "$sub" in
    --prune)
      local inv entries pruned=0
      inv="$(_orphans_load_inventory)"
      entries="$(echo "$inv" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for name, info in d.get('binaries',{}).items():
    print(f'{name}|{info.get(\"binary_path\",\"?\")}')
" 2>/dev/null)"

      while IFS='|' read -r name path; do
        [[ -z "$name" ]] && continue
        if [[ ! -f "$path" ]]; then
          _orphans_remove_entry "$name"
          pruned=$((pruned + 1))
        fi
      done <<<"$entries"

      echo "  ✓ Pruned ${pruned} stale inventory entries"
      ;;
    *)
      _crisp_list_orphans
      echo
      echo "  ${DIM}crisp scan-orphans   — full detection scan${RST}"
      echo "  ${DIM}crisp check-orphans  — compare versions${RST}"
      echo "  ${DIM}crisp update-orphans — batch update behind binaries${RST}"
      echo "  ${DIM}crisp list-orphans   — list tracked binaries${RST}"
      echo "  ${DIM}crisp uninstall <n>  — remove binary from tracking${RST}"
      echo "  ${DIM}crisp orphans --prune — clean stale entries${RST}"
      ;;
  esac
}

# ─────────────────────────────────────────────────
# Module runner
# ─────────────────────────────────────────────────
crisp_orphans_run() {
  echo "  → Orphan binary check..."
  _crisp_check_orphans
}
