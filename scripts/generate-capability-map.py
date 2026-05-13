#!/usr/bin/env python3

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
METADATA = ROOT / "ofxggml-addon.json"
OUTPUT = ROOT / "docs" / "capability-map.md"


def main():
    data = json.loads(METADATA.read_text(encoding="utf-8"))

    lines = [
        "# Addon Capability Map",
        "",
        "This file is generated from `ofxggml-addon.json`.",
        "",
        f"Addon: `{data.get('name', '')}`",
        f"Lane: `{data.get('lane', '')}`",
        f"Core baseline: `{data.get('coreBaseline', '')}`",
        "",
        "## Requires",
        "",
    ]

    for item in data.get("requires", []):
        lines.append(f"- `{item}`")

    lines.extend(["", "## Owns", ""])
    for item in data.get("owns", []):
        lines.append(f"- {item}")

    lines.extend(["", "## Platforms", ""])
    for item in data.get("platforms", []):
        lines.append(f"- `{item}`")

    lines.extend(["", "## Backends", ""])
    for item in data.get("backends", []):
        lines.append(f"- `{item}`")

    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
