#!/usr/bin/env python3

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ecosystem.json"
OUTPUT = ROOT / "docs" / "release-readiness-score.md"


def main():
    ecosystem = json.loads(MANIFEST.read_text(encoding="utf-8"))
    baseline = ecosystem.get("baseline", "unknown")
    required_files = ecosystem.get("required_files", [])

    repos = []
    core = ecosystem.get("core", {})
    if core.get("repo"):
        repos.append({"repo": core.get("repo"), "lane": "core"})
    for addon in ecosystem.get("addons", []):
        repos.append({"repo": addon.get("repo"), "lane": addon.get("lane", "")})

    lines = [
        "# Release Readiness Score",
        "",
        "This report is generated from ecosystem policy metadata.",
        "",
        f"Baseline: `{baseline}`",
        "",
        "## Policy coverage",
        "",
        f"Required file policy count: `{len(required_files)}`",
        f"Tracked repositories: `{len(repos)}`",
        "",
        "## Repository readiness checklist",
        "",
        "| Repository | Lane | Metadata | Shared workflow | Release check | Status |",
        "| --- | --- | --- | --- | --- | --- |",
    ]

    for record in repos:
        repo = record.get("repo", "")
        lane = record.get("lane", "")
        lines.append(f"| `{repo}` | `{lane}` | expected | expected | expected | planned |")

    lines.extend([
        "",
        "## Notes",
        "",
        "- This is a policy-derived readiness score, not a live CI result.",
        "- Future versions should combine this report with live workflow status and metadata reconciliation output.",
        "- Release readiness should eventually distinguish declared, validated, and released capabilities.",
    ])

    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
