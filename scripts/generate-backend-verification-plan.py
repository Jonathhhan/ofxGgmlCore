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
        "| graph-smoke-checked | A lightweight ggml graph compute/readback smoke test succeeds |",
        "| inference-checked | A minimal model/inference smoke test succeeds |",
        "",
        "## Repository backend validation targets",
        "",
        "| Repository | Lane | Backend validation target | Current status |",
        "| --- | --- | --- | --- |",
    ]

    for record in repos:
        if record["repo"] == "Jonathhhan/ofxGgmlCore":
            target = "`backend-runtime-check` CPU runtime smoke"
            status = "runtime-checked and graph-smoke-checked on CI"
        else:
            target = "from `ofxggml-addon.json`"
            status = "planned"
        lines.append(f"| `{record['repo']}` | `{record['lane']}` | {target} | {status} |")

    lines.extend([
        "",
        "## Active runtime checks",
        "",
        "- Core runs `backend-runtime-check` on relevant pull requests and pushes to `main`.",
        "- The reusable workflow initializes the CPU backend and runs a lightweight ggml graph compute/readback smoke on Windows and Ubuntu.",
        "- The macOS lane currently verifies the runtime-smoke scaffold without compiling the local ggml runtime.",
        "- Local Windows validation can require CUDA with `scripts\\build-runtime-smoke.ps1 -Backend cpu,cuda -RequireBackend`.",
        "",
        "## Initial runtime checks",
        "",
        "- keep backend discovery commands/scripts available",
        "- keep CPU backend initialization and graph smoke active in CI",
        "- verify optional GPU backends are reported as available/unavailable without failing the whole workflow",
        "- separate hard failures from optional backend absence",
        "",
        "## Future runtime checks",
        "",
        "- model-backed CPU inference smoke test with tiny fixture",
        "- CUDA runtime discovery in a GPU-capable runner",
        "- Metal runtime initialization and graph smoke on macOS",
        "- Vulkan runtime discovery where available",
        "- backend capability report uploaded as release evidence from CI",
    ])

    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
