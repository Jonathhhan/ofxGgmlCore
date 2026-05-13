#!/usr/bin/env sh
set -eu
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
rc_ps1="$script_dir/release-candidate.ps1"
if command -v pwsh >/dev/null 2>&1; then
	pwsh -NoProfile -ExecutionPolicy Bypass -File "$rc_ps1" "$@"
elif command -v powershell >/dev/null 2>&1; then
	powershell -NoProfile -ExecutionPolicy Bypass -File "$rc_ps1" "$@"
else
	echo "PowerShell 7+ is required to run release-candidate.ps1" >&2
	exit 1
fi
