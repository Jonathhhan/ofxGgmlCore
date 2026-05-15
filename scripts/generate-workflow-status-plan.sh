#!/usr/bin/env sh
set -eu
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if command -v python3 >/dev/null 2>&1; then
	python3 "$script_dir/generate-workflow-status-plan.py" "$@"
elif command -v python >/dev/null 2>&1; then
	python "$script_dir/generate-workflow-status-plan.py" "$@"
else
	echo "Python is required to run generate-workflow-status-plan.py" >&2
	exit 1
fi
