#!/usr/bin/env bash

set -e

if [ -z "$1" ]; then
  echo "Usage: ./scripts/bootstrap-addon.sh <AddonName>"
  exit 1
fi

ADDON_NAME="$1"

mkdir -p "$ADDON_NAME"
cd "$ADDON_NAME"

mkdir -p src
mkdir -p examples
mkdir -p scripts
mkdir -p docs
mkdir -p .github/workflows
mkdir -p .codex/skills/openframeworks-addon

cat > README.md <<EOF
# $ADDON_NAME

Part of the ofxGgml ecosystem.
EOF

cat > CHANGELOG.md <<EOF
# Changelog

## Unreleased
EOF

cat > AGENTS.md <<EOF
# AGENTS.md

Repository guidance for $ADDON_NAME.
EOF

cat > addon_config.mk <<EOF
meta:
	ADDON_NAME = $ADDON_NAME
EOF

echo "Bootstrapped $ADDON_NAME"
