#!/usr/bin/env python3

import json
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ecosystem.json"
REPORT = ROOT / "docs" / "metadata-reconciliation-report.md"


def raw_metadata_url(repo: str) -> str:
    owner, name = repo.split("/", 1)
    return f"https://raw.githubusercontent.com/{owner}/{name}/main/ofxggml-addon.json"


def fetch_json(url: str):
    with urllib.request.urlopen(url, timeout=20) as response:
        return json.loads(response.read().decode("utf-8"))


def expected_records(ecosystem):
    core = ecosystem.get("core", {})
    if core.get("repo"):
        yield {"name": core.get("repo", "").split("/")[-1], "repo": core.get("repo", ""), "lane": "core", "requires_core": False}
    for addon in ecosystem.get("addons", []):
        yield {"name": addon.get("name", ""), "repo": addon.get("repo", ""), "lane": addon.get("lane", ""), "requires_core": True}


def main():
    ecosystem = json.loads(MANIFEST.read_text(encoding="utf-8"))
    baseline = ecosystem.get("baseline", "unknown")
    lines = [
        "# Metadata Reconciliation Report",
        "",
        "This report reconciles `ecosystem.json` with each repository's `ofxggml-addon.json`.",
        "",
        f"Expected baseline: `{baseline}`",
        "",
        "| Repository | Expected lane | Metadata name | Metadata lane | Baseline | Status |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    failed = False
    for expected in expected_records(ecosystem):
        repo = expected["repo"]
        try:
            metadata = fetch_json(raw_metadata_url(repo))
            name = metadata.get("name", "missing")
            lane = metadata.get("lane", "missing")
            declared_baseline = metadata.get("coreBaseline", "missing")
            problems = []
            if name != expected["name"]:
                problems.append("name mismatch")
            if lane != expected["lane"]:
                problems.append("lane mismatch")
            if declared_baseline != baseline:
                problems.append("baseline mismatch")
            if expected["requires_core"] and "ofxGgmlCore" not in metadata.get("requires", []):
                problems.append("missing Core dependency")
            status = "OK" if not problems else "; ".join(problems)
            failed = failed or bool(problems)
            lines.append(f"| `{repo}` | `{expected['lane']}` | `{name}` | `{lane}` | `{declared_baseline}` | {status} |")
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, ValueError) as exc:
            failed = True
            lines.append(f"| `{repo}` | `{expected['lane']}` | unavailable | unavailable | unavailable | fetch failed: {exc.__class__.__name__} |")
    lines.extend(["", "## Notes", "", "- Uses public raw GitHub metadata from each registered repository.", "- Companion addons should declare `ofxGgmlCore` in `requires`.", "- Declared `coreBaseline` should match the ecosystem baseline unless an exception is documented."])
    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {REPORT.relative_to(ROOT)}")
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
