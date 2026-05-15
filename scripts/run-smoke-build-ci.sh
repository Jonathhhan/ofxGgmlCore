#!/usr/bin/env sh
set -eu
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
smoke_build_ci_ps1="$script_dir/run-smoke-build-ci.ps1"
if command -v pwsh >/dev/null 2>&1; then
	pwsh -NoProfile -ExecutionPolicy Bypass -File "$smoke_build_ci_ps1" "$@"
elif command -v powershell >/dev/null 2>&1; then
	powershell -NoProfile -ExecutionPolicy Bypass -File "$smoke_build_ci_ps1" "$@"
else
	echo "PowerShell 7+ is required to run run-smoke-build-ci.ps1" >&2
	exit 1
fi
