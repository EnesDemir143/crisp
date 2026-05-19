#!/usr/bin/env bash
# crisp core: recipes — trusted update recipes for known tools

[[ -n "${CRISP_RECIPES_LOADED:-}" ]] && return 0
readonly CRISP_RECIPES_LOADED=1

declare -A CRISP_RECIPES

# Recipe format: key=tool_name, value="update_command||version_check"
CRISP_RECIPES["hermes"]="hermes update||hermes --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'"
CRISP_RECIPES["omx"]="omx update||omx --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'"
CRISP_RECIPES["graphify"]="graphify update||graphify --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'"

# Check if a tool has a trusted recipe
_recipe_exists() { [[ -n "${CRISP_RECIPES[$1]:+x}" ]]; }

# Get the update command for a recipe
_recipe_update() { echo "${CRISP_RECIPES[$1]%%||*}"; }

# Get the version check for a recipe
_recipe_version_check() { echo "${CRISP_RECIPES[$1]##*||}"; }
