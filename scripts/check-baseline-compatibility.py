#!/usr/bin/env python3

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ecosystem.json"
REPORT = ROOT / "docs" / "baseline-compatibility-report.md"


def main():
    ecosystem = json.loads(MANIFEST.read_text(encoding="utf-8"))
    baseline = ecosystem.get("baseline", "unknown")

    metadata_files = list(ROOT.glob("**/ofxggml-addon.json"))

    lines = [
        "# Baseline Compatibility Report",
        "",
        f"Expected baseline: `{baseline}`",
        "",
        "| Addon | Declared baseline | Status |",
        "| --- | --- | --- |",
    ]

    failed = False

    for path in metadata_files:
        data = json.loads(path.read_text(encoding="utf-8"))
        declared = data.get("coreBaseline", "missing")
        status = "OK" if declared == baseline else "MISMATCH"

        if status != "OK":
            failed = True

        lines.append(f"| `{data.get('name', path.parent.name)}` | `{declared}` | `{status}` |")

    lines.extend([
        "",
        "## Notes",
        "",
        "- Companion addons should remain aligned with the ecosystem baseline where practical.",
        "- Breaking Core changes should trigger compatibility review.",
    ])

    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {REPORT.relative_to(ROOT)}")

    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
