#!/usr/bin/env python3

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ecosystem.json"
OUTPUT = ROOT / "docs" / "workflow-fanout-plan.md"

WORKFLOWS = [
    "addon-hygiene.yml",
    "release-check.yml",
]


def main():
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))

    lines = []
    lines.append("# Workflow Fanout Plan")
    lines.append("")
    lines.append("Repositories expected to consume reusable workflows from `ofxGgmlWorkflows`.")
    lines.append("")
    lines.append("| Repository | Workflow | Target |")
    lines.append("| --- | --- | --- |")

    repos = [data.get("core", {}).get("repo", "")]
    repos.extend(addon.get("repo", "") for addon in data.get("addons", []))

    for repo in repos:
        for workflow in WORKFLOWS:
            target = f"Jonathhhan/ofxGgmlWorkflows/.github/workflows/{workflow}@main"
            lines.append(f"| `{repo}` | `{workflow}` | `{target}` |")

    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append("- Companion repos should minimize local workflow logic.")
    lines.append("- Shared CI behavior should live in `ofxGgmlWorkflows`.")
    lines.append("- Ecosystem-wide CI upgrades should happen centrally whenever possible.")

    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
