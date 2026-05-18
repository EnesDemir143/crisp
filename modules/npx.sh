#!/bin/bash
# crisp module: npx
# Clears npx cache (removes stale packages)

crisp_npx_run() {
  echo "  → NPx cache cleanup..."
  npx clear-cache 2>&1 | tail -1 || true
  echo "    ✓ NPx cache cleared"
}
