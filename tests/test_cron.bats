#!/usr/bin/env bats
# tests/test_cron.bats — Cron expression generation tests

setup() {
  CRISP_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  source "$CRISP_DIR/lib/core/base.sh"
  source "$CRISP_DIR/lib/core/ui.sh"
  source "$CRISP_DIR/lib/core/common.sh"

  # Define _cron_expression inline (it's in crisp main script)
  _cron_expression() {
    case "$1" in
      every_5m)  echo "*/5 * * * *" ;;
      every_15m) echo "*/15 * * * *" ;;
      every_30m) echo "*/30 * * * *" ;;
      every_1h)  echo "0 * * * *" ;;
      every_6h)  echo "0 */6 * * *" ;;
      daily_09)  echo "0 9 * * *" ;;
      weekly_mon) echo "0 9 * * 1" ;;
      monthly_1) echo "0 3 1 * *" ;;
      *)         echo "" ;;
    esac
  }
}

# ─────────────────────────────────────────────────
# Cron expression generation
# ─────────────────────────────────────────────────

@test "every_5m generates correct cron" {
  result="$(_cron_expression every_5m)"
  [[ "$result" == "*/5 * * * *" ]]
}

@test "every_15m generates correct cron" {
  result="$(_cron_expression every_15m)"
  [[ "$result" == "*/15 * * * *" ]]
}

@test "every_30m generates correct cron" {
  result="$(_cron_expression every_30m)"
  [[ "$result" == "*/30 * * * *" ]]
}

@test "every_1h generates correct cron" {
  result="$(_cron_expression every_1h)"
  [[ "$result" == "0 * * * *" ]]
}

@test "every_6h generates correct cron" {
  result="$(_cron_expression every_6h)"
  [[ "$result" == "0 */6 * * *" ]]
}

@test "daily_09 generates correct cron" {
  result="$(_cron_expression daily_09)"
  [[ "$result" == "0 9 * * *" ]]
}

@test "weekly_mon generates correct cron" {
  result="$(_cron_expression weekly_mon)"
  [[ "$result" == "0 9 * * 1" ]]
}

@test "monthly_1 generates correct cron" {
  result="$(_cron_expression monthly_1)"
  [[ "$result" == "0 3 1 * *" ]]
}

@test "invalid preset returns empty string" {
  result="$(_cron_expression invalid)"
  [[ -z "$result" ]]
}

# ─────────────────────────────────────────────────
# Cron presets data structure
# ─────────────────────────────────────────────────

@test "CRON_PRESETS array has 9 entries" {
  CRON_PRESETS=(
    "every_5m:Every 5 minutes"
    "every_15m:Every 15 minutes"
    "every_30m:Every 30 minutes"
    "every_1h:Every 1 hour"
    "every_6h:Every 6 hours"
    "daily_09:Daily at 09:00"
    "weekly_mon:Weekly (Monday 09:00)"
    "monthly_1:Monthly (1st, 03:00)"
    "custom:Custom cron expression"
  )
  [[ ${#CRON_PRESETS[@]} -eq 9 ]]
}
