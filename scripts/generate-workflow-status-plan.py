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
        "This document defines the workflow status signals that feed ecosystem health and release readiness.",
        "Use `scripts\\fetch-workflow-status.py --stale-days 30` for the live GitHub Actions report.",
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
        "## Live report path",
        "",
        "- query latest workflow runs per repository with `scripts\\fetch-workflow-status.py`",
        "- distinguish skipped, failed, cancelled, and successful runs in the generated workflow status report",
        "- block release trains on failed, missing, unavailable, or stale required workflows when `--strict` is used",
        "- surface stale repositories with no recent workflow runs using the configured stale-day threshold",
        "- fold live CI status into release readiness through `scripts\\plan-release-readiness.bat`",
        "",
        "## Current status",
        "",
        "The live workflow-status report is implemented separately so this plan can stay deterministic and offline-friendly.",
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
