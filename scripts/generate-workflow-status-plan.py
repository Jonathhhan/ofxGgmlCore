#!/usr/bin/env python3

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ecosystem.json"
OUTPUT = ROOT / "docs" / "workflow-status-plan.md"

WORKFLOWS = [
    {"name": "addon-hygiene", "scope": "all managed repositories"},
    {"name": "release-check", "scope": "all managed repositories"},
    {"name": "metadata-validation", "scope": "all managed repositories"},
    {"name": "baseline-compatibility", "scope": "all managed repositories"},
    {"name": "release-gate", "scope": "Core release control", "repos": ["Jonathhhan/ofxGgmlCore"]},
]


def parse_args():
    parser = argparse.ArgumentParser(description="Generate the ofxGgml workflow status planning report.")
    parser.add_argument("--output", default=str(OUTPUT), help="Markdown report path.")
    return parser.parse_args()


def main():
    args = parse_args()
    ecosystem = json.loads(MANIFEST.read_text(encoding="utf-8"))

    repos = []
    core = ecosystem.get("core", {})
    if core.get("repo"):
        repos.append({"repo": core.get("repo"), "lane": "core"})
    for addon in ecosystem.get("addons", []):
        repos.append({"repo": addon.get("repo"), "lane": addon.get("lane", "")})

    lines = [
        "# Workflow Status Plan",
        "",
        "This document defines the workflow status signals that should eventually feed ecosystem health and release readiness.",
        "",
        "| Repository | Lane | Expected workflow | Scope | Status source |",
        "| --- | --- | --- | --- | --- |",
    ]

    for repo in repos:
        for workflow in WORKFLOWS:
            workflow_repos = workflow.get("repos")
            if workflow_repos and repo["repo"] not in workflow_repos:
                continue
            lines.append(
                f"| `{repo['repo']}` | `{repo['lane']}` | `{workflow['name']}` | {workflow['scope']} | GitHub Actions |"
            )

    lines.extend([
        "",
        "## Future live checks",
        "",
        "- query latest workflow runs per repository",
        "- distinguish skipped, failed, cancelled, and successful runs",
        "- block release trains on failed required workflows",
        "- surface stale repositories with no recent workflow runs",
        "- combine live CI status with metadata reconciliation reports",
        "",
        "## Current status",
        "",
        "This is a planning scaffold. It does not yet query GitHub Actions APIs.",
    ])

    output = Path(args.output)
    if not output.is_absolute():
        output = ROOT / output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8")
    try:
        display_path = output.relative_to(ROOT)
    except ValueError:
        display_path = output
    print(f"Wrote {display_path}")


if __name__ == "__main__":
    main()
