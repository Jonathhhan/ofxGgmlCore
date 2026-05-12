#!/usr/bin/env python3

from pathlib import Path
from datetime import datetime

ROOT = Path(__file__).resolve().parents[1]
CHANGELOG = ROOT / "CHANGELOG.md"


def main():
    timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")

    template = f'''# Changelog

## Unreleased

### Added

- Describe new features here.

### Changed

- Describe changes here.

### Fixed

- Describe fixes here.

---

Generated template refreshed: {timestamp}
'''

    CHANGELOG.write_text(template, encoding="utf-8")
    print(f"Updated {CHANGELOG.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
