#!/bin/bash
# crisp module: graphify
# Updates the graphifyy pip package + version file

crisp_graphify_run() {
  echo "  → Updating graphify..."

  # graphify installed under miniconda, find correct pip
  local pip_cmd=""
  for candidate in \
    "/opt/homebrew/Caskroom/miniconda/base/bin/python3 -m pip" \
    "pip3" \
    "python3 -m pip"; do
    if $candidate show graphifyy &>/dev/null; then
      pip_cmd="$candidate"
      break
    fi
  done

  if [ -z "$pip_cmd" ]; then
    echo "    ⚠ graphify not found, skipping"
    return
  fi

  $pip_cmd install --upgrade graphifyy 2>&1 | grep -E "Successfully|already satisfied|graphifyy" | head -1
  echo "    ✓ graphify updated"
}
