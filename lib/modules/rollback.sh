#!/usr/bin/env bash
# crisp module: rollback
# Backup snapshots + restore + cleanup + safety checks for crisp-updated binaries.

[[ -n "${CRISP_MOD_ROLLBACK_LOADED:-}" ]] && return 0
readonly CRISP_MOD_ROLLBACK_LOADED=1

CRISP_DATA_HOME="${CRISP_DATA_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/crisp}"
CRISP_BACKUP_DIR="${CRISP_DATA_HOME}/backups"

# ─────────────────────────────────────────────────
# T12: Pre-update backup
# ─────────────────────────────────────────────────

_crisp_backup_binary() {
  local name="$1" version="$2" binary="$3"

  [[ -z "$name" || -z "$version" || -z "$binary" ]] && return 1
  [[ -f "$binary" ]] || return 2

  local backup_dir="${CRISP_BACKUP_DIR}/${name}/${version}"
  mkdir -p "$backup_dir"

  local checksum
  checksum=$(shasum -a 256 "$binary" | cut -d' ' -f1)

  cp "$binary" "${backup_dir}/$(basename "$binary")"

  cat >"${backup_dir}/metadata.json" <<EOF
{"name":"${name}","version":"${version}","date":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","source":"${binary}","checksum":"${checksum}"}
EOF

  return 0
}

# ─────────────────────────────────────────────────
# T13: Rollback command
# ─────────────────────────────────────────────────

_crisp_rollback_list() {
  if [[ ! -d "$CRISP_BACKUP_DIR" ]] || [[ -z "$(ls -A "$CRISP_BACKUP_DIR" 2>/dev/null)" ]]; then
    echo "    ⚠ No backups found"
    return 0
  fi

  echo "📦 Available backups"
  echo "──────────────────────────────"

  for name_dir in "$CRISP_BACKUP_DIR"/*/; do
    [[ -d "$name_dir" ]] || continue
    local name
    name=$(basename "$name_dir")
    echo "${name}:"

    for version_dir in "$name_dir"/*/; do
      [[ -d "$version_dir" ]] || continue
      local version meta_file date checksum
      version=$(basename "$version_dir")
      meta_file="${version_dir}/metadata.json"

      if [[ -f "$meta_file" ]]; then
        date=$(grep -o '"date":"[^"]*"' "$meta_file" | head -1 | sed 's/"date":"//;s/"//')
        checksum=$(grep -o '"checksum":"[^"]*"' "$meta_file" | head -1 | sed 's/"checksum":"//;s/"//')
        echo "    ${version}  (${date}) sha256:${checksum}"
      else
        echo "    ${version}  (no metadata)"
      fi
    done
  done
}

_crisp_rollback_do() {
  local name="$1" version="${2:-}" meta_file source_path backup_path

  if [[ -z "$name" ]]; then
    _crisp_rollback_list
    return 0
  fi

  # Determine version: latest if not specified
  if [[ -z "$version" ]]; then
    local latest=""
    for vdir in "$CRISP_BACKUP_DIR/$name"/*/; do
      [[ -d "$vdir" ]] || continue
      local v
      v=$(basename "$vdir")
      [[ "$v" > "$latest" ]] && latest="$v"
    done
    if [[ -z "$latest" ]]; then
      echo "    ⚠ No backups found for '${name}'"
      return 1
    fi
    version="$latest"
  fi

  meta_file="${CRISP_BACKUP_DIR}/${name}/${version}/metadata.json"
  if [[ ! -f "$meta_file" ]]; then
    echo "    ⚠ Backup not found: ${name} v${version}"
    return 1
  fi

  # Read metadata
  source_path=$(grep -o '"source":"[^"]*"' "$meta_file" | sed 's/"source":"//;s/"//')
  local expected_checksum
  expected_checksum=$(grep -o '"checksum":"[^"]*"' "$meta_file" | sed 's/"checksum":"//;s/"//')

  backup_path="${CRISP_BACKUP_DIR}/${name}/${version}/$(basename "$source_path")"

  # T15: Safety check — backup file exists
  if [[ ! -f "$backup_path" ]]; then
    echo "    ⚠ Backup file missing: ${backup_path}"
    return 1
  fi

  # T15: Safety check — checksum matches metadata
  local actual_checksum
  actual_checksum=$(shasum -a 256 "$backup_path" | cut -d' ' -f1)
  if [[ "$actual_checksum" != "$expected_checksum" ]]; then
    echo "    ⚠ Checksum mismatch, aborted"
    return 1
  fi

  # Show version diff before restore
  local current_version=""
  if [[ -f "$source_path" ]]; then
    current_version=$(grep -o '"version":"[^"]*"' "$meta_file" | sed 's/"version":"//;s/"//')
    echo "  → ${name}: v${current_version} → v${version} (downgrade)"
  fi

  # Restore
  cp "$backup_path" "$source_path"
  chmod +x "$source_path"

  # T15: Safety check — binary is executable after restore
  if [[ ! -x "$source_path" ]]; then
    echo "    ⚠ Restored binary is not executable: ${source_path}"
    return 1
  fi

  echo "    ✓ Restored ${name} to v${version}"
  return 0
}

_crisp_rollback_cmd() {
  case "${1:-}" in
    --list | -l)
      _crisp_rollback_list
      ;;
    *)
      _crisp_rollback_do "$@"
      ;;
  esac
}

# ─────────────────────────────────────────────────
# T14: Backup cleanup
# ─────────────────────────────────────────────────

_crisp_clean_backups() {
  local remove_all=false
  [[ "${1:-}" == "--all" ]] && remove_all=true

  if [[ ! -d "$CRISP_BACKUP_DIR" ]]; then
    echo "  → No backups to clean"
    return 0
  fi

  # Remove all mode
  if [[ "$remove_all" == "true" ]]; then
    local all_count
    all_count=$(find "$CRISP_BACKUP_DIR" -name "metadata.json" | wc -l | tr -d ' ')
    echo -n "  → Remove all ${all_count} backups? (y/N): "
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo "    ⚠ Cancelled"
      return 0
    fi
    rm -rf "$CRISP_BACKUP_DIR"
    echo "    ✓ Removed all ${all_count} backups"
    return 0
  fi

  # Age-based cleanup
  local retention_days="${CRISP_BACKUP_RETENTION_DAYS:-30}"
  local removed=0 kept=0 cutoff_date

  cutoff_date=$(date -u -d "${retention_days} days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null) || {
    # macOS date compatibility
    cutoff_date=$(date -u -v -"${retention_days}"d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null) || {
      echo "    ⚠ Unable to compute cutoff date"
      return 1
    }
  }

  while IFS= read -r meta_file; do
    local backup_date version_dir
    backup_date=$(grep -o '"date":"[^"]*"' "$meta_file" | head -1 | sed 's/"date":"//;s/"//')
    if [[ -z "$backup_date" ]]; then
      kept=$((kept + 1))
      continue
    fi

    if [[ "$backup_date" < "$cutoff_date" ]]; then
      version_dir=$(dirname "$meta_file")
      rm -rf "$version_dir"
      removed=$((removed + 1))
    else
      kept=$((kept + 1))
    fi
  done < <(find "$CRISP_BACKUP_DIR" -name "metadata.json" 2>/dev/null)

  # Clean empty parent dirs
  find "$CRISP_BACKUP_DIR" -type d -empty -delete 2>/dev/null

  echo "    ✓ Removed ${removed} old backups, ${kept} kept"
  return 0
}

_crisp_clean_backups_cmd() {
  _crisp_clean_backups "${1:-}"
}
