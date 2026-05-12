#!/usr/bin/env python3

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FIELDS = [
    "name",
    "lane",
    "coreBaseline",
    "requires",
    "owns",
    "platforms",
    "backends",
]


def validate_file(path: Path):
    data = json.loads(path.read_text(encoding="utf-8"))

    missing = [field for field in REQUIRED_FIELDS if field not in data]

    if missing:
        print(f"[FAIL] {path}: missing fields: {', '.join(missing)}")
        return False

    print(f"[OK] {path}")
    return True


def main():
    metadata_files = list(ROOT.glob("**/ofxggml-addon.json"))

    if not metadata_files:
        print("No metadata files found")
        raise SystemExit(1)

    success = True

    for metadata_file in metadata_files:
        success = validate_file(metadata_file) and success

    if not success:
        raise SystemExit(1)

    print("Metadata validation passed")


if __name__ == "__main__":
    main()
