#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script_path="$script_dir/plan-backend-runtime-verification.ps1"

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -ExecutionPolicy Bypass -File "$script_path" "$@"
elif command -v powershell >/dev/null 2>&1; then
  powershell -NoProfile -ExecutionPolicy Bypass -File "$script_path" "$@"
else
  echo "PowerShell is required to run plan-backend-runtime-verification.ps1." >&2
  exit 127
fi
