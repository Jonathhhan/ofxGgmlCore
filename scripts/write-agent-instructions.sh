#!/usr/bin/env sh
set -eu
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
agent_ps1="$script_dir/write-agent-instructions.ps1"
if command -v pwsh >/dev/null 2>&1; then
	pwsh -NoProfile -ExecutionPolicy Bypass -File "$agent_ps1" "$@"
elif command -v powershell >/dev/null 2>&1; then
	powershell -NoProfile -ExecutionPolicy Bypass -File "$agent_ps1" "$@"
else
	echo "PowerShell 7+ is required to run write-agent-instructions.ps1" >&2
	exit 1
fi
