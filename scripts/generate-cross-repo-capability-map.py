#!/usr/bin/env python3

import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ecosystem.json"
OUTPUT = ROOT / "docs" / "cross-repo-capability-map.md"


def metadata_url(repo):
    owner, name = repo.split("/", 1)
    return f"https://raw.githubusercontent.com/{owner}/{name}/main/ofxggml-addon.json"


def fetch_metadata(repo):
    with urllib.request.urlopen(metadata_url(repo), timeout=20) as response:
        return json.loads(response.read().decode("utf-8"))


def repos_from_manifest(ecosystem):
    core_repo = ecosystem.get("core", {}).get("repo")
    if core_repo:
        yield core_repo
    for addon in ecosystem.get("addons", []):
        repo = addon.get("repo")
        if repo:
            yield repo


def main():
    ecosystem = json.loads(MANIFEST.read_text(encoding="utf-8"))
    lines = [
        "# Cross-Repo Capability Map",
        "",
        "Generated from each repository's `ofxggml-addon.json` metadata.",
        "",
        "| Repository | Addon | Lane | Baseline | Platforms | Backends | Status |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    failed = False
    for repo in repos_from_manifest(ecosystem):
        try:
            data = fetch_metadata(repo)
            platforms = ", ".join(data.get("platforms", []))
            backends = ", ".join(data.get("backends", []))
            lines.append(f"| `{repo}` | `{data.get('name', '')}` | `{data.get('lane', '')}` | `{data.get('coreBaseline', '')}` | {platforms} | {backends} | OK |")
        except Exception as exc:
            failed = True
            lines.append(f"| `{repo}` | unavailable | unavailable | unavailable | unavailable | unavailable | fetch failed: {exc.__class__.__name__} |")
    lines.extend(["", "## Notes", "", "- This report reflects declared metadata, not native build validation.", "- Backend/platform declarations should later be checked against CI coverage."])
    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
