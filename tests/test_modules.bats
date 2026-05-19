#!/usr/bin/env bats
# tests/test_modules.bats — Module loading and execution tests

setup() {
  CRISP_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export CRISP_DIR
  source "$CRISP_DIR/lib/core/base.sh"
  source "$CRISP_DIR/lib/core/ui.sh"
  source "$CRISP_DIR/lib/core/common.sh"
}

# ─────────────────────────────────────────────────
# Module path resolution
# ─────────────────────────────────────────────────

@test "_module_path returns correct path for brew" {
  result="$(_module_path brew)"
  [[ "$result" == "$CRISP_MODULES_DIR/brew.sh" ]]
}

@test "_module_path returns correct path for pip" {
  result="$(_module_path pip)"
  [[ "$result" == "$CRISP_MODULES_DIR/pip.sh" ]]
}

@test "_module_path returns path for nonexistent module" {
  result="$(_module_path nonexistent)"
  [[ "$result" == "$CRISP_MODULES_DIR/nonexistent.sh" ]]
}

# ─────────────────────────────────────────────────
# Module description
# ─────────────────────────────────────────────────

@test "_module_desc returns description for brew" {
  result="$(_module_desc brew)"
  [[ "$result" == *"brew"* ]]
}

@test "_module_desc returns description for pip" {
  result="$(_module_desc pip)"
  [[ "$result" == *"pip"* ]]
}

@test "_module_desc returns 'custom module' for unknown" {
  result="$(_module_desc foobar)"
  [[ "$result" == "custom module" ]]
}

# ─────────────────────────────────────────────────
# Module count
# ─────────────────────────────────────────────────

@test "_module_count returns correct count" {
  CRISP_MODULES="brew pip npm"
  result="$(_module_count)"
  [[ "$result" -eq 3 ]]
}

@test "_module_count returns 0 for empty" {
  CRISP_MODULES=""
  result="$(_module_count)"
  [[ "$result" -eq 0 ]]
}

# ─────────────────────────────────────────────────
# Module execution
# ─────────────────────────────────────────────────

@test "_run_module nonexistent returns error" {
  run _run_module "nonexistent"
  [[ "$status" -eq 1 ]]
}

@test "_run_module nonexistent shows error message" {
  run _run_module "nonexistent"
  [[ "$output" == *"not found"* ]]
}

@test "_run_module dry-run shows would-run message" {
  export CRISP_DRY_RUN=true
  run _run_module "brew"
  [[ "$output" == *"would run"* ]]
}

@test "_run_module dry-run returns success" {
  export CRISP_DRY_RUN=true
  run _run_module "brew"
  [[ "$status" -eq 0 ]]
}

# ─────────────────────────────────────────────────
# Guard-based sourcing
# ─────────────────────────────────────────────────

@test "sourcing base.sh twice does not error" {
  source "$CRISP_DIR/lib/core/base.sh"
  source "$CRISP_DIR/lib/core/base.sh"
  # Should not produce errors
  [[ "$CRISP_OS" == "macos" ]] || [[ "$CRISP_OS" == "linux" ]]
}

@test "sourcing ui.sh twice does not error" {
  source "$CRISP_DIR/lib/core/ui.sh"
  source "$CRISP_DIR/lib/core/ui.sh"
  declare -F read_key &>/dev/null
}

@test "sourcing common.sh twice does not error" {
  source "$CRISP_DIR/lib/core/common.sh"
  source "$CRISP_DIR/lib/core/common.sh"
  declare -F _run_module &>/dev/null
}

# ─────────────────────────────────────────────────
# All modules sourceable
# ─────────────────────────────────────────────────

@test "all module files pass bash syntax check" {
  for f in "$CRISP_MODULES_DIR"/*.sh; do
    bash -n "$f" || {
      echo "Syntax error in: $(basename "$f")"
      return 1
    }
  done
}
