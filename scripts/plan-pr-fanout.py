#!/usr/bin/env python3

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ecosystem.json"
OUTPUT = ROOT / "docs" / "pr-fanout-plan.md"


def main():
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))

    repos = [data.get("core", {}).get("repo", "")]
    repos.extend(addon.get("repo", "") for addon in data.get("addons", []))
    repos = [repo for repo in repos if repo]

    lines = [
        "# PR Fanout Plan",
        "",
        "Use this checklist when propagating ecosystem-wide changes across the ofxGgml repositories.",
        "",
        "## Target repositories",
        "",
    ]

    for repo in repos:
        lines.append(f"- [ ] `{repo}`")

    lines.extend([
        "",
        "## Recommended fanout flow",
        "",
        "1. Prepare the change in `ofxGgmlCore` or `ofxGgmlWorkflows`.",
        "2. Validate the source change.",
        "3. Create one small PR per companion repo.",
        "4. Keep branch names consistent across repos.",
        "5. Run hygiene and release checks.",
        "6. Merge from Core outward, then companion addons.",
        "7. Update `ecosystem.json`, dashboard, compatibility matrix, and release plan.",
        "",
        "## Branch naming",
        "",
        "```txt",
        "ecosystem/<short-change-name>",
        "```",
        "",
        "## PR body template",
        "",
        "```md",
        "## Summary",
        "Propagates ecosystem-wide standard updates.",
        "",
        "## Scope",
        "- [ ] workflow/config only",
        "- [ ] docs only",
        "- [ ] code change",
        "",
        "## Validation",
        "- [ ] addon-hygiene",
        "- [ ] release-check",
        "```",
    ])

    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
