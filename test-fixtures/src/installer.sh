#!/usr/bin/env bash
set -euo pipefail

# Install a plugin from the marketplace
install_plugin() {
  local plugin_name="$1"
  local target_dir="$2"

  # Find plugin in marketplace
  local marketplace_file=".claude-plugin/marketplace.json"
  if [[ ! -f "$marketplace_file" ]]; then
    echo "Error: marketplace.json not found"
    return 1
  fi

  local info
  info=$(jq -r ".plugins[] | select(.name == \"${plugin_name}\")" "$marketplace_file")

  if [[ -z "$info" ]]; then
    echo "Plugin not found: ${plugin_name}"
    return 1
  fi

  local src
  src=$(echo "$info" | jq -r '.path')

  # Copy plugin files
  if [[ -d "$src" ]]; then
    cp -r "$src" "${target_dir}/${plugin_name}"
    echo "Installed ${plugin_name} to ${target_dir}"
  else
    echo "Source directory not found: ${src}"
    return 1
  fi

  # Run post-install hooks
  local hooks_file="${target_dir}/${plugin_name}/hooks/hooks.json"
  if [[ -f "$hooks_file" ]]; then
    local scripts
    scripts=$(jq -r '.PostInstall[]?.command // empty' "$hooks_file")
    for script in $scripts; do
      eval "$script"
    done
  fi
}

# Parse arguments
if [[ $# -lt 2 ]]; then
  echo "Usage: installer.sh <plugin-name> <target-dir>"
  exit 1
fi

install_plugin "$1" "$2"
