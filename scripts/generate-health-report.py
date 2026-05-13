#!/usr/bin/env python3

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ecosystem.json"
OUTPUT = ROOT / "docs" / "ecosystem-health-report.md"


def main():
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    baseline = data.get("baseline", "unknown")
    required_files = data.get("required_files", [])

    lines = [
        "# Ecosystem Health Report",
        "",
        "This report is generated from `ecosystem.json`.",
        "",
        f"Baseline: `{baseline}`",
        "",
        "## Required files tracked by policy",
        "",
    ]

    for file_name in required_files:
        lines.append(f"- `{file_name}`")

    lines.extend([
        "",
        "## Repositories",
        "",
        "| Repository | Role/Lane | Expected status |",
        "| --- | --- | --- |",
    ])

    core = data.get("core", {})
    lines.append(f"| `{core.get('repo', '')}` | Core | governed |")

    for addon in data.get("addons", []):
        lines.append(f"| `{addon.get('repo', '')}` | `{addon.get('lane', '')}` | governed |")

    lines.extend([
        "",
        "## Health signals",
        "",
        "- Central reusable workflows should live in `Jonathhhan/ofxGgmlWorkflows`.",
        "- Companion repos should consume reusable workflows where practical.",
        "- Addon boundaries should remain aligned with `ecosystem.json`.",
        "- Generated artifacts and models should remain outside git.",
        "",
    ])

    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
