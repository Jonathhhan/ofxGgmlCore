#!/usr/bin/env bash

set -e

ROOT_FILES=(
  "README.md"
  "addon_config.mk"
  "CHANGELOG.md"
  "AGENTS.md"
)

GITHUB_FILES=(
  ".github/copilot-instructions.md"
  ".github/pull_request_template.md"
  ".github/workflows/addon-hygiene.yml"
  ".github/workflows/release-check.yml"
)

missing=0

for file in "${ROOT_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo "Missing required file: $file"
    missing=1
  fi
done

for file in "${GITHUB_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo "Missing GitHub workflow/template file: $file"
    missing=1
  fi
done

if [ ! -f "ecosystem.json" ]; then
  echo "Missing ecosystem.json"
  missing=1
fi

if [ "$missing" -eq 0 ]; then
  echo "Ecosystem checklist passed"
else
  echo "Ecosystem checklist failed"
  exit 1
fi
