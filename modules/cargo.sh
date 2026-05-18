#!/bin/bash
# crisp module: cargo
# Updates Rust cargo installs (requires cargo-install-update)

crisp_cargo_run() {
  if ! command -v cargo-install-update &>/dev/null && ! command -v cargo-update &>/dev/null; then
    echo "  → Cargo: cargo-update tool not found (optional, skipped)"
    return
  fi

  echo "  → Cargo update..."
  cargo install-update -a 2>&1 | tail -5
  echo "    ✓ Cargo packages updated"
}
