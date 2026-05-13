#!/usr/bin/env python3

import json
from pathlib import Path
from datetime import datetime

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ecosystem.json"
OUTPUT = ROOT / "docs" / "release-plan.md"


def main():
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))

    baseline = data.get("baseline", "unknown")
    timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")

    lines = [
        "# Ecosystem Release Plan",
        "",
        f"Generated: {timestamp}",
        "",
        f"Target baseline: `{baseline}`",
        "",
        "## Repositories",
        "",
    ]

    core = data.get("core", {})
    lines.append(f"- `{core.get('repo', '')}` (Core)")

    for addon in data.get("addons", []):
        lines.append(f"- `{addon.get('repo', '')}` ({addon.get('lane', '')})")

    lines.extend([
        "",
        "## Coordinated release checklist",
        "",
        "- [ ] hygiene workflows passing",
        "- [ ] release-check workflows passing",
        "- [ ] dashboards regenerated",
        "- [ ] changelogs updated",
        "- [ ] compatibility matrix regenerated",
        "- [ ] artifact policy validated",
        "- [ ] addon boundaries reviewed",
        "",
    ])

    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
