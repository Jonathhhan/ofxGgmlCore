#!/usr/bin/env bash

set -e

if [ -z "$1" ]; then
  echo "Usage: ./scripts/bootstrap-addon.sh <AddonName> [TemplateRepo]"
  echo "Example: ./scripts/bootstrap-addon.sh ofxMyAddon https://github.com/openframeworks/ofxAddonTemplate"
  exit 1
fi

ADDON_NAME="$1"
TEMPLATE_REPO="${2:-https://github.com/openframeworks/ofxAddonTemplate}"
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADDON_PATH="$WORKSPACE_ROOT/$ADDON_NAME"
TMP_DIR="$(mktemp -d)"

cleanup() {
  if [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

if [ -e "$ADDON_PATH" ]; then
  echo "Addon folder already exists: $ADDON_PATH"
  exit 1
fi

mkdir -p "$ADDON_PATH"

template_source=""
if command -v git >/dev/null 2>&1 && ( [[ "$TEMPLATE_REPO" == http* ]] || [[ "$TEMPLATE_REPO" == git@* ]] ); then
  echo "Bootstrapping $ADDON_NAME from template: $TEMPLATE_REPO"
  if git clone --depth 1 "$TEMPLATE_REPO" "$TMP_DIR/template" >/tmp/bootstrap-addon.log 2>&1; then
    template_source="$TMP_DIR/template"
  else
    echo "Template clone failed; fallback to minimal scaffold"
    template_source=""
  fi
elif [ -d "$TEMPLATE_REPO" ]; then
  echo "Bootstrapping $ADDON_NAME from local template path: $TEMPLATE_REPO"
  template_source="$TEMPLATE_REPO"
fi

if [ -n "$template_source" ]; then
  cp -R "$template_source"/. "$ADDON_PATH/"
  rm -rf "$ADDON_PATH/.git"

  # Normalize template placeholders and old-ofx template workflow remnants for
  # this ecosystem.
  if [ -f "$ADDON_PATH/README_DEPLOY.md" ]; then
    rm -f "$ADDON_PATH/README.md"
    mv "$ADDON_PATH/README_DEPLOY.md" "$ADDON_PATH/README.md"
  fi
  rm -f "$ADDON_PATH/README_AUTHOR.md"
  rm -f "$ADDON_PATH/.appveyor.yml"
  rm -f "$ADDON_PATH/.travis.yml"
else
  mkdir -p "$ADDON_PATH/src"
  mkdir -p "$ADDON_PATH/examples"
  mkdir -p "$ADDON_PATH/scripts"
  mkdir -p "$ADDON_PATH/docs"
  mkdir -p "$ADDON_PATH/.github/workflows"
  mkdir -p "$ADDON_PATH/.codex/skills/openframeworks-addon"

  cat > "$ADDON_PATH/README.md" <<EOF
# $ADDON_NAME

Part of the ofxGgml ecosystem.
EOF

  cat > "$ADDON_PATH/CHANGELOG.md" <<EOF
# Changelog

## Unreleased
EOF

  cat > "$ADDON_PATH/AGENTS.md" <<EOF
# AGENTS.md

Repository guidance for $ADDON_NAME.
EOF

  cat > "$ADDON_PATH/addon_config.mk" <<EOF
meta:
	ADDON_NAME = $ADDON_NAME
EOF
fi

if [ -f "$ADDON_PATH/README.md" ]; then
  perl -0pi -e "s/ofxAddonTemplate/$ADDON_NAME/g" "$ADDON_PATH/README.md" 2>/dev/null || true
  perl -0pi -e "s/MyAddon \\(rename to your addon's name\\)/$ADDON_NAME/g" "$ADDON_PATH/README.md" 2>/dev/null || true
fi

echo "Bootstrapped $ADDON_NAME at $ADDON_PATH"
