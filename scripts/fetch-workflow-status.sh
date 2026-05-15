#!/usr/bin/env sh
set -eu
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
if command -v python3 >/dev/null 2>&1; then
	python3 "$script_dir/fetch-workflow-status.py" "$@"
elif command -v python >/dev/null 2>&1; then
	python "$script_dir/fetch-workflow-status.py" "$@"
else
	echo "Python is required to run fetch-workflow-status.py" >&2
	exit 1
fi
