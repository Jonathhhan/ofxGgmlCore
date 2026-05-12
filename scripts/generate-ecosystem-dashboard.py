#!/usr/bin/env python3

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ecosystem.json"
DASHBOARD = ROOT / "docs" / "ecosystem-dashboard.md"
GRAPH = ROOT / "docs" / "ecosystem-dependency-graph.md"


def load_manifest():
    with MANIFEST.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_dashboard(data):
    lines = []
    lines.append("# ofxGgml Ecosystem Dashboard")
    lines.append("")
    lines.append(f"Baseline: `{data.get('baseline', 'unknown')}`")
    lines.append("")
    lines.append("## Core")
    lines.append("")
    core = data.get("core", {})
    lines.append(f"- Repo: `{core.get('repo', '')}`")
    lines.append(f"- Role: {core.get('role', '')}")
    lines.append("")
    lines.append("## Addons")
    lines.append("")
    lines.append("| Addon | Lane | Repository | Owns |")
    lines.append("| --- | --- | --- | --- |")
    for addon in data.get("addons", []):
        owns = ", ".join(addon.get("owns", []))
        lines.append(f"| `{addon.get('name', '')}` | `{addon.get('lane', '')}` | `{addon.get('repo', '')}` | {owns} |")
    lines.append("")
    lines.append("## Required files")
    lines.append("")
    for item in data.get("required_files", []):
        lines.append(f"- `{item}`")
    lines.append("")
    lines.append("## Artifact policy")
    lines.append("")
    policy = data.get("artifact_policy", {})
    lines.append("Forbidden extensions:")
    for item in policy.get("forbidden_extensions", []):
        lines.append(f"- `{item}`")
    lines.append("")
    lines.append("Forbidden directories:")
    for item in policy.get("forbidden_directories", []):
        lines.append(f"- `{item}`")
    lines.append("")
    DASHBOARD.write_text("\n".join(lines), encoding="utf-8")


def write_graph(data):
    lines = []
    lines.append("# ofxGgml Dependency Graph")
    lines.append("")
    lines.append("```mermaid")
    lines.append("graph TD")
    lines.append("  Core[ofxGgmlCore]")
    for addon in data.get("addons", []):
        safe_name = addon.get("name", "addon").replace("-", "_")
        lane = addon.get("lane", "")
        lines.append(f"  Core --> {safe_name}[{addon.get('name', '')}: {lane}]")
    lines.append("```")
    lines.append("")
    lines.append("All companion addons should depend on Core for shared backend-neutral primitives and keep domain-specific workflows in their own repository.")
    lines.append("")
    GRAPH.write_text("\n".join(lines), encoding="utf-8")


def main():
    data = load_manifest()
    write_dashboard(data)
    write_graph(data)
    print(f"Wrote {DASHBOARD.relative_to(ROOT)}")
    print(f"Wrote {GRAPH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
