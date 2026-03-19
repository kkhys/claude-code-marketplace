#!/usr/bin/env bash
set -euo pipefail

# Marketplace utilities for listing and searching plugins

list_plugins() {
  local marketplace_file=".claude-plugin/marketplace.json"
  if [[ ! -f "$marketplace_file" ]]; then
    echo "No marketplace found"
    return 1
  fi

  local data
  data=$(cat "$marketplace_file")
  local count
  count=$(echo "$data" | jq '.plugins | length')

  echo "Available plugins (${count}):"
  echo "$data" | jq -r '.plugins[] | "  \(.name)@\(.version) - \(.description)"'
}

search_plugins() {
  local query="$1"
  local marketplace_file=".claude-plugin/marketplace.json"

  if [[ ! -f "$marketplace_file" ]]; then
    echo "No marketplace found"
    return 1
  fi

  local results
  results=$(jq -r ".plugins[] | select(.name + .description | test(\"${query}\"; \"i\"))" "$marketplace_file")

  if [[ -z "$results" ]]; then
    echo "No plugins matching: ${query}"
    return 0
  fi

  echo "$results" | jq -r '"  \(.name)@\(.version) - \(.description)"'
}

get_plugin_info() {
  local name="$1"
  local marketplace_file=".claude-plugin/marketplace.json"

  local info
  info=$(jq ".plugins[] | select(.name == \"${name}\")" "$marketplace_file")

  if [[ -z "$info" ]]; then
    echo "Plugin not found: ${name}"
    return 1
  fi

  echo "$info" | jq '.'
}

# Main
case "${1:-}" in
  list)
    list_plugins
    ;;
  search)
    search_plugins "${2:?Usage: marketplace.sh search <query>}"
    ;;
  info)
    get_plugin_info "${2:?Usage: marketplace.sh info <name>}"
    ;;
  *)
    echo "Usage: marketplace.sh {list|search|info} [args]"
    exit 1
    ;;
esac
