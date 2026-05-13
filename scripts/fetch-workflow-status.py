#!/usr/bin/env python3

import json
import os
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ecosystem.json"
OUTPUT = ROOT / "docs" / "workflow-status-report.md"

WORKFLOWS = [
    "addon-hygiene.yml",
    "release-check.yml",
    "metadata-validation.yml",
    "baseline-compatibility.yml",
]


def github_json(url):
    headers = {"Accept": "application/vnd.github+json"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.loads(response.read().decode("utf-8"))


def repos_from_manifest(ecosystem):
    core = ecosystem.get("core", {}).get("repo")
    if core:
        yield core
    for addon in ecosystem.get("addons", []):
        repo = addon.get("repo")
        if repo:
            yield repo


def latest_workflow_status(repo, workflow):
    url = f"https://api.github.com/repos/{repo}/actions/workflows/{workflow}/runs?per_page=1"
    data = github_json(url)
    runs = data.get("workflow_runs", [])
    if not runs:
        return "no runs"
    run = runs[0]
    conclusion = run.get("conclusion") or run.get("status") or "unknown"
    return f"{conclusion} ({run.get('html_url', '')})"


def main():
    ecosystem = json.loads(MANIFEST.read_text(encoding="utf-8"))
    lines = [
        "# Workflow Status Report",
        "",
        "This report fetches latest GitHub Actions workflow status where available.",
        "",
        "| Repository | Workflow | Latest status |",
        "| --- | --- | --- |",
    ]
    failed = False
    for repo in repos_from_manifest(ecosystem):
        for workflow in WORKFLOWS:
            try:
                status = latest_workflow_status(repo, workflow)
            except Exception as exc:
                failed = True
                status = f"unavailable: {exc.__class__.__name__}"
            lines.append(f"| `{repo}` | `{workflow}` | {status} |")
    lines.extend([
        "",
        "## Notes",
        "",
        "- Set `GITHUB_TOKEN` for higher API limits and private-repo access.",
        "- Missing workflows are reported as unavailable or no runs.",
        "- This report is observational and should later feed release gating.",
    ])
    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
