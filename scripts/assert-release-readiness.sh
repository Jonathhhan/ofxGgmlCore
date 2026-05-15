#!/usr/bin/env sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
pwsh -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/assert-release-readiness.ps1" "$@"
