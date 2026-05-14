#!/usr/bin/env sh
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if command -v pwsh >/dev/null 2>&1; then
	exec pwsh -ExecutionPolicy Bypass -NoProfile -File "$SCRIPT_DIR/plan-smoke-build-project-repair.ps1" "$@"
fi
exec powershell -ExecutionPolicy Bypass -NoProfile -File "$SCRIPT_DIR/plan-smoke-build-project-repair.ps1" "$@"
