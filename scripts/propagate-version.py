#!/usr/bin/env python3

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ecosystem.json"
OUTPUT = ROOT / "docs" / "version-propagation-plan.md"


def main():
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    baseline = data.get("baseline", "unknown")

    repos = [data.get("core", {}).get("repo", "")]
    repos.extend(addon.get("repo", "") for addon in data.get("addons", []))
    repos = [repo for repo in repos if repo]

    lines = [
        "# Version Propagation Plan",
        "",
        f"Target baseline: `{baseline}`",
        "",
        "## Repositories targeted for synchronization",
        "",
    ]

    for repo in repos:
        lines.append(f"- [ ] `{repo}`")

    lines.extend([
        "",
        "## Recommended propagation flow",
        "",
        "1. Update `ecosystem.json` baseline.",
        "2. Regenerate dashboards, matrices, and plans.",
        "3. Update Core governance/workflows first.",
        "4. Propagate reusable workflow updates.",
        "5. Update companion addon changelogs.",
        "6. Validate release-check and addon-hygiene workflows.",
        "7. Tag coordinated ecosystem release if appropriate.",
        "",
    ])

    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
