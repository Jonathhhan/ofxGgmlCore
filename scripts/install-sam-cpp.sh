#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADDON_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEST_DIR="${ADDON_ROOT}/libs/sam.cpp"

SAM_CPP_REPO="${OFXGGML_SAM_CPP_REPO:-https://github.com/YavorGIvanov/sam.cpp.git}"
SAM_CPP_REF="${OFXGGML_SAM_CPP_REF:-81002818eb0e2cb3b9a523286b067f80f8424431}"

if ! command -v git >/dev/null 2>&1; then
	echo "git is required to install sam.cpp" >&2
	exit 1
fi

mkdir -p "${ADDON_ROOT}/libs"

if [ -d "${DEST_DIR}/.git" ]; then
	echo "==> Updating existing sam.cpp checkout in ${DEST_DIR}"
	git -C "${DEST_DIR}" fetch --tags origin
else
	if [ -e "${DEST_DIR}" ] && [ -n "$(find "${DEST_DIR}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
		echo "Refusing to overwrite non-empty directory: ${DEST_DIR}" >&2
		exit 1
	fi
	rm -rf "${DEST_DIR}"
	echo "==> Cloning sam.cpp into ${DEST_DIR}"
	git clone --recursive "${SAM_CPP_REPO}" "${DEST_DIR}"
fi

git -C "${DEST_DIR}" checkout "${SAM_CPP_REF}"
git -C "${DEST_DIR}" submodule update --init --recursive

cat <<EOF
==> sam.cpp is installed.

Source: ${DEST_DIR}
Ref:    ${SAM_CPP_REF}

The openFrameworks Project Generator can now see sam.h and sam.cpp through
addon_config.mk. Regenerate ofxGgmlGuiExample after installing.

To use the GUI SAM panel, convert a Segment Anything checkpoint following:
  https://github.com/ggml-org/ggml/tree/master/examples/sam
EOF
