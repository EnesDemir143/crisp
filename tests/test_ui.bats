#!/usr/bin/env bats
# tests/test_ui.bats — UI key handling tests

setup() {
  CRISP_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$CRISP_DIR/lib/core/base.sh"
  source "$CRISP_DIR/lib/core/ui.sh"
}

# ─────────────────────────────────────────────────
# read_key — arrow key sequences
# ─────────────────────────────────────────────────

@test "read_key returns UP for ESC [ A" {
  result=$(echo -e '\x1b[A' | bash -c "
    source '$CRISP_DIR/lib/core/base.sh'
    source '$CRISP_DIR/lib/core/ui.sh'
    read_key
  ")
  [[ "$result" == "UP" ]]
}

@test "read_key returns DOWN for ESC [ B" {
  result=$(echo -e '\x1b[B' | bash -c "
    source '$CRISP_DIR/lib/core/base.sh'
    source '$CRISP_DIR/lib/core/ui.sh'
    read_key
  ")
  [[ "$result" == "DOWN" ]]
}

@test "read_key returns RIGHT for ESC [ C" {
  result=$(echo -e '\x1b[C' | bash -c "
    source '$CRISP_DIR/lib/core/base.sh'
    source '$CRISP_DIR/lib/core/ui.sh'
    read_key
  ")
  [[ "$result" == "RIGHT" ]]
}

@test "read_key returns LEFT for ESC [ D" {
  result=$(echo -e '\x1b[D' | bash -c "
    source '$CRISP_DIR/lib/core/base.sh'
    source '$CRISP_DIR/lib/core/ui.sh'
    read_key
  ")
  [[ "$result" == "LEFT" ]]
}

# ─────────────────────────────────────────────────
# read_key — vim bindings
# ─────────────────────────────────────────────────

@test "read_key returns DOWN for j" {
  result=$(echo 'j' | bash -c "
    source '$CRISP_DIR/lib/core/base.sh'
    source '$CRISP_DIR/lib/core/ui.sh'
    read_key
  ")
  [[ "$result" == "DOWN" ]]
}

@test "read_key returns UP for k" {
  result=$(echo 'k' | bash -c "
    source '$CRISP_DIR/lib/core/base.sh'
    source '$CRISP_DIR/lib/core/ui.sh'
    read_key
  ")
  [[ "$result" == "UP" ]]
}

@test "read_key returns QUIT for q" {
  result=$(echo 'q' | bash -c "
    source '$CRISP_DIR/lib/core/base.sh'
    source '$CRISP_DIR/lib/core/ui.sh'
    read_key
  ")
  [[ "$result" == "QUIT" ]]
}

@test "read_key returns HELP for h" {
  result=$(echo 'h' | bash -c "
    source '$CRISP_DIR/lib/core/base.sh'
    source '$CRISP_DIR/lib/core/ui.sh'
    read_key
  ")
  [[ "$result" == "HELP" ]]
}

@test "read_key returns VERSION for v" {
  result=$(echo 'v' | bash -c "
    source '$CRISP_DIR/lib/core/base.sh'
    source '$CRISP_DIR/lib/core/ui.sh'
    read_key
  ")
  [[ "$result" == "VERSION" ]]
}

@test "read_key returns TOP for g" {
  result=$(echo 'g' | bash -c "
    source '$CRISP_DIR/lib/core/base.sh'
    source '$CRISP_DIR/lib/core/ui.sh'
    read_key
  ")
  [[ "$result" == "TOP" ]]
}

# ─────────────────────────────────────────────────
# read_key — number keys
# ─────────────────────────────────────────────────

@test "read_key returns NUM:1 for key 1" {
  result=$(echo '1' | bash -c "
    source '$CRISP_DIR/lib/core/base.sh'
    source '$CRISP_DIR/lib/core/ui.sh'
    read_key
  ")
  [[ "$result" == "NUM:1" ]]
}

@test "read_key returns NUM:9 for key 9" {
  result=$(echo '9' | bash -c "
    source '$CRISP_DIR/lib/core/base.sh'
    source '$CRISP_DIR/lib/core/ui.sh'
    read_key
  ")
  [[ "$result" == "NUM:9" ]]
}

# ─────────────────────────────────────────────────
# read_key — Enter key
# ─────────────────────────────────────────────────

@test "read_key returns ENTER for empty input (newline)" {
  result=$(echo '' | bash -c "
    source '$CRISP_DIR/lib/core/base.sh'
    source '$CRISP_DIR/lib/core/ui.sh'
    read_key
  ")
  [[ "$result" == "ENTER" ]]
}

# ─────────────────────────────────────────────────
# Terminal control functions exist
# ─────────────────────────────────────────────────

@test "hide_cursor function exists" {
  declare -F hide_cursor &>/dev/null
}

@test "show_cursor function exists" {
  declare -F show_cursor &>/dev/null
}

@test "clear_screen function exists" {
  declare -F clear_screen &>/dev/null
}

@test "press_any_key function exists" {
  declare -F press_any_key &>/dev/null
}

@test "_draw_header function exists" {
  declare -F _draw_header &>/dev/null
}

@test "_draw_footer function exists" {
  declare -F _draw_footer &>/dev/null
}

@test "_draw_divider function exists" {
  declare -F _draw_divider &>/dev/null
}

@test "_draw_menu_items function exists" {
  declare -F _draw_menu_items &>/dev/null
}
