#!/usr/bin/env bash
set -euo pipefail

# Play a notification sound. afplay and the system sounds are macOS-only, so
# exit quietly elsewhere instead of failing the hook on Linux or in
# devcontainers.

readonly SOUND="${1:?Usage: play-sound.sh <sound-file>}"

if ! command -v afplay > /dev/null 2>&1 || [[ ! -f "${SOUND}" ]]; then
  exit 0
fi

exec afplay "${SOUND}"
