#!/usr/bin/env bats
# tests/test_config_picker.bats — Config picker and _save_config_modules tests

setup() {
  CRISP_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export CRISP_DIR

  # Set vars that base.sh makes readonly BEFORE sourcing
  export CRISP_HOME="$CRISP_DIR"
  export XDG_CONFIG_HOME="${BATS_TMPDIR:-/tmp}/crisp-test-config/config"
  export XDG_DATA_HOME="${BATS_TMPDIR:-/tmp}/crisp-test-config/data"
  export XDG_CACHE_HOME="${BATS_TMPDIR:-/tmp}/crisp-test-config/cache"
  mkdir -p "$XDG_CONFIG_HOME/crisp" "$XDG_DATA_HOME/crisp" "$XDG_CACHE_HOME/crisp"

  source "$CRISP_DIR/lib/core/base.sh"

  # Override mutable vars after sourcing base.sh
  export CRISP_CONF="$CRISP_CONFIG_HOME/crisp.conf"
  export CRISP_MODULES_DIR="$CRISP_DIR/lib/modules"

  source "$CRISP_DIR/lib/core/common.sh"

  # Create a default test config
  echo 'CRISP_MODULES="brew pip npm"' > "$CRISP_CONF"
  CRISP_MODULES="brew pip npm"
}

teardown() {
  rm -rf "${BATS_TMPDIR:-/tmp}/crisp-test-config"
}

# ─────────────────────────────────────────────────
# _module_desc
# ─────────────────────────────────────────────────

@test "config: _module_desc returns description for known module" {
  result="$(_module_desc brew)"
  [[ "$result" == *"brew"* ]]
}

@test "config: _module_desc returns description for pip" {
  result="$(_module_desc pip)"
  [[ "$result" == *"pip"* ]]
}

@test "config: _module_desc returns generic for unknown module" {
  result="$(_module_desc nonexistent_module)"
  [[ "$result" == "custom module" ]]
}

# ─────────────────────────────────────────────────
# _all_available_modules
# ─────────────────────────────────────────────────

@test "config: _all_available_modules lists module names" {
  run _all_available_modules
  [[ "$output" == *"brew"* ]]
}

@test "config: _all_available_modules lists multiple modules" {
  run _all_available_modules
  [[ "$output" == *"pip"* ]]
  [[ "$output" == *"npm"* ]]
}

# ─────────────────────────────────────────────────
# _save_config_modules — inline definition (matches crisp main script)
# ─────────────────────────────────────────────────

_save_config_modules() {
  local new_modules="$1"
  local dir
  dir="$(dirname "$CRISP_CONF")"
  mkdir -p "$dir" 2>/dev/null
  if [[ -f "$CRISP_CONF" ]]; then
    if grep -q "^CRISP_MODULES=" "$CRISP_CONF" 2>/dev/null; then
      if [[ "$CRISP_OS" == "macos" ]]; then
        sed -i '' "s/^CRISP_MODULES=.*/CRISP_MODULES=\"${new_modules}\"/" "$CRISP_CONF"
      else
        sed -i "s/^CRISP_MODULES=.*/CRISP_MODULES=\"${new_modules}\"/" "$CRISP_CONF"
      fi
    else
      echo "CRISP_MODULES=\"${new_modules}\"" >>"$CRISP_CONF"
    fi
  else
    echo "CRISP_MODULES=\"${new_modules}\"" >"$CRISP_CONF"
  fi
  CRISP_MODULES="$new_modules"
}

@test "config: _save_config_modules creates config file if missing" {
  local test_conf="${BATS_TMPDIR:-/tmp}/crisp-test-config/new.conf"
  export CRISP_CONF="$test_conf"
  _save_config_modules "brew pip"
  [ -f "$test_conf" ]
  run grep "CRISP_MODULES" "$test_conf"
  [[ "$output" == *"brew pip"* ]]
}

@test "config: _save_config_modules updates existing line" {
  local test_conf="${BATS_TMPDIR:-/tmp}/crisp-test-config/update.conf"
  echo 'CRISP_MODULES="brew pip"' > "$test_conf"
  export CRISP_CONF="$test_conf"
  _save_config_modules "brew npm"
  run cat "$test_conf"
  [[ "$output" == *"brew npm"* ]]
  [[ "$output" != *"brew pip"* ]]
}

@test "config: _save_config_modules preserves comments" {
  local test_conf="${BATS_TMPDIR:-/tmp}/crisp-test-config/comment.conf"
  {
    echo "# This is a comment"
    echo 'CRISP_MODULES="brew pip"'
    echo "# Another comment"
  } > "$test_conf"
  export CRISP_CONF="$test_conf"
  _save_config_modules "npm"
  run cat "$test_conf"
  [[ "$output" == *"# This is a comment"* ]]
  [[ "$output" == *"# Another comment"* ]]
}

@test "config: _save_config_modules appends CRISP_MODULES line if missing" {
  local test_conf="${BATS_TMPDIR:-/tmp}/crisp-test-config/no-line.conf"
  echo "# No CRISP_MODULES here" > "$test_conf"
  export CRISP_CONF="$test_conf"
  _save_config_modules "brew"
  run cat "$test_conf"
  [[ "$output" == *"CRISP_MODULES="* ]]
}

@test "config: _save_config_modules does not error on empty modules" {
  local test_conf="${BATS_TMPDIR:-/tmp}/crisp-test-config/empty.conf"
  echo 'CRISP_MODULES="brew pip"' > "$test_conf"
  export CRISP_CONF="$test_conf"
  run _save_config_modules ""
  [ "$status" -eq 0 ]
  # Accepts empty modules (sets CRISP_MODULES to empty string)
  run cat "$test_conf"
  [[ "$output" == *'CRISP_MODULES=""'* ]]
}

# ─────────────────────────────────────────────────
# Main script syntax validation
# ─────────────────────────────────────────────────

@test "config: main script passes bash syntax check" {
  run bash -n "$CRISP_DIR/crisp"
  [ "$status" -eq 0 ]
}

@test "config: common.sh passes bash syntax check" {
  run bash -n "$CRISP_DIR/lib/core/common.sh"
  [ "$status" -eq 0 ]
}

@test "config: base.sh passes bash syntax check" {
  run bash -n "$CRISP_DIR/lib/core/base.sh"
  [ "$status" -eq 0 ]
}

@test "config: ui.sh passes bash syntax check" {
  run bash -n "$CRISP_DIR/lib/core/ui.sh"
  [ "$status" -eq 0 ]
}
