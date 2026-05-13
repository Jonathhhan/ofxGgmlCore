#!/usr/bin/env bash

set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required for CI runtime smoke setup"
  exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake is required for CI runtime smoke setup"
  exit 1
fi

if ! command -v pwsh >/dev/null 2>&1 && ! command -v powershell >/dev/null 2>&1; then
  echo "PowerShell is required by scripts/setup-ggml.sh"
  exit 1
fi

"$root_dir/scripts/setup-ggml.sh" -CpuOnly -Jobs 2
"$root_dir/scripts/build-runtime-smoke.sh"
