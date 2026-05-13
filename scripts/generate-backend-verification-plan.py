#!/usr/bin/env python3

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ecosystem.json"
OUTPUT = ROOT / "docs" / "backend-verification-plan.md"


def main():
    ecosystem = json.loads(MANIFEST.read_text(encoding="utf-8"))
    backends = sorted(set(ecosystem.get("artifact_policy", {}).get("declared_backends", [])))

    repos = []
    core = ecosystem.get("core", {})
    if core.get("repo"):
        repos.append({"repo": core.get("repo"), "lane": "core"})
    for addon in ecosystem.get("addons", []):
        repos.append({"repo": addon.get("repo"), "lane": addon.get("lane", "")})

    lines = [
        "# Backend Verification Plan",
        "",
        "This document defines how declared backend support should become validated backend support.",
        "",
        "## Verification levels",
        "",
        "| Level | Meaning |",
        "| --- | --- |",
        "| declared | Listed in `ofxggml-addon.json` |",
        "| build-checked | CI compiled code paths for the backend |",
        "| runtime-checked | Backend initialization succeeds in CI or local validation |",
        "| inference-checked | A minimal model/inference smoke test succeeds |",
        "",
        "## Repository backend validation targets",
        "",
        "| Repository | Lane | Backend validation target | Current status |",
        "| --- | --- | --- | --- |",
    ]

    for record in repos:
        lines.append(f"| `{record['repo']}` | `{record['lane']}` | from `ofxggml-addon.json` | planned |")

    lines.extend([
        "",
        "## Initial runtime checks",
        "",
        "- verify backend discovery commands/scripts exist",
        "- verify CPU backend can initialize without model files",
        "- verify optional GPU backends are reported as available/unavailable without failing the whole workflow",
        "- separate hard failures from optional backend absence",
        "",
        "## Future runtime checks",
        "",
        "- minimal ggml context allocation",
        "- CPU inference smoke test with tiny fixture",
        "- CUDA runtime discovery",
        "- Metal runtime discovery on macOS",
        "- Vulkan runtime discovery where available",
        "- backend capability report uploaded as CI artifact",
    ])

    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
