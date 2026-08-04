#!/usr/bin/env bash
set -euo pipefail

# Throwaway: makes ShellCheck fail so the babysitting CI-failure path can be
# exercised against a real workflow run. Deleted in the following commit.
target=$1
echo $target
