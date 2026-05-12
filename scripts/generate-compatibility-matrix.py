#!/usr/bin/env python3

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ecosystem.json"
OUTPUT = ROOT / "docs" / "compatibility-matrix.md"


def main():
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    baseline = data.get("baseline", "unknown")

    lines = [
        "# ofxGgml Compatibility Matrix",
        "",
        "This file is generated from `ecosystem.json`.",
        "",
        f"Baseline: `{baseline}`",
        "",
        "| Addon | Lane | Core baseline | Repository | Status |",
        "| --- | --- | --- | --- | --- |",
    ]

    for addon in data.get("addons", []):
        lines.append(
            f"| `{addon.get('name', '')}` | `{addon.get('lane', '')}` | `{baseline}` | `{addon.get('repo', '')}` | tracked |"
        )

    lines.extend([
        "",
        "## Notes",
        "",
        "- Companion addons should document their minimum supported `ofxGgmlCore` baseline.",
        "- Breaking Core changes should trigger companion-addon validation.",
        "- Domain workflows should remain in their owning companion addon.",
        "",
    ])

    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
