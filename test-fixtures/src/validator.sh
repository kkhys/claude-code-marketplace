#!/usr/bin/env bash
set -euo pipefail

# Validate plugin structure
validate_plugin() {
  local dir="$1"

  # Check plugin.json exists
  if [[ ! -f "${dir}/.claude-plugin/plugin.json" ]]; then
    echo "Missing plugin.json"
    return 1
  fi

  # Read and validate plugin.json
  local data
  data=$(cat "${dir}/.claude-plugin/plugin.json")

  local name
  name=$(echo "$data" | jq -r '.name')
  local version
  version=$(echo "$data" | jq -r '.version')

  if [[ -z "$name" || "$name" == "null" ]]; then
    echo "Plugin name is required"
    return 1
  fi

  # Validate version format
  if ! echo "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Invalid version format"
    return 1
  fi

  # Check for commands directory
  if [[ -d "${dir}/commands" ]]; then
    for cmd in "${dir}"/commands/*.md; do
      [[ -f "$cmd" ]] || continue
      # Just check if file is readable
      cat "$cmd" > /dev/null
    done
  fi

  echo "Validation passed for ${name}@${version}"
}

# Process arguments
if [[ $# -eq 0 ]]; then
  echo "Usage: validator.sh <plugin-dir> [plugin-dir...]"
  exit 1
fi

for arg in "$@"; do
  validate_plugin "$arg"
done
