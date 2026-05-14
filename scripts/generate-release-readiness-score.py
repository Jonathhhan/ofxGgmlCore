#!/usr/bin/env python3

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ecosystem.json"
OUTPUT = ROOT / "docs" / "release-readiness-score.md"


def parse_args():
    parser = argparse.ArgumentParser(description="Generate an ofxGgml ecosystem release-readiness score.")
    parser.add_argument("--output", default=str(OUTPUT), help="Markdown report path.")
    parser.add_argument("--workflow-status-report", default="", help="Optional workflow status markdown report to fold into release evidence.")
    return parser.parse_args()


def parse_workflow_status_report(path):
    if not path:
        return None

    report = Path(path)
    if not report.is_absolute():
        report = ROOT / report
    if not report.exists():
        raise FileNotFoundError(f"workflow status report was not found: {report}")

    metrics = {}
    for line in report.read_text(encoding="utf-8").splitlines():
        match = re.match(r"- (.+): `(\d+)`", line)
        if match:
            metrics[match.group(1)] = int(match.group(2))
    return {
        "path": str(report),
        "metrics": metrics,
    }


def workflow_evidence_status(workflow_report):
    if not workflow_report:
        return "not provided"

    metrics = workflow_report["metrics"]
    blockers = (
        metrics.get("Blocking latest runs", 0) +
        metrics.get("Missing required workflows", 0) +
        metrics.get("Required workflows with no runs", 0) +
        metrics.get("Unavailable required statuses", 0) +
        metrics.get("Stale required workflows", 0)
    )
    if blockers > 0:
        return f"blocked by {blockers} required workflow signal(s)"
    return "no required workflow blockers reported"


def main():
    args = parse_args()
    ecosystem = json.loads(MANIFEST.read_text(encoding="utf-8"))
    baseline = ecosystem.get("baseline", "unknown")
    required_files = ecosystem.get("required_files", [])
    workflow_report = parse_workflow_status_report(args.workflow_status_report)

    repos = []
    core = ecosystem.get("core", {})
    if core.get("repo"):
        repos.append({"repo": core.get("repo"), "lane": "core"})
    for addon in ecosystem.get("addons", []):
        repos.append({"repo": addon.get("repo"), "lane": addon.get("lane", "")})

    lines = [
        "# Release Readiness Score",
        "",
        "This report is generated from ecosystem policy metadata.",
        "",
        f"Baseline: `{baseline}`",
        "",
        "## Policy coverage",
        "",
        f"Required file policy count: `{len(required_files)}`",
        f"Tracked repositories: `{len(repos)}`",
        "",
        "## Evidence inputs",
        "",
        "- Local validation: expected before release",
        "- Strict ecosystem audit: expected before release",
        "- Ecosystem readiness check: expected before release",
        f"- Workflow status report: `{workflow_evidence_status(workflow_report)}`",
        "",
    ]

    if workflow_report:
        lines.extend([
            "### Workflow status evidence",
            "",
            "| Metric | Count |",
            "| --- | ---: |",
        ])
        for key in (
            "Successful latest runs",
            "Blocking latest runs",
            "Missing required workflows",
            "Required workflows with no runs",
            "Unavailable required statuses",
            "Stale required workflows",
        ):
            lines.append(f"| {key} | {workflow_report['metrics'].get(key, 0)} |")
        lines.append("")

    lines.extend([
        "## Repository readiness checklist",
        "",
        "| Repository | Lane | Metadata | Shared workflow | Release check | Status |",
        "| --- | --- | --- | --- | --- | --- |",
    ])

    for record in repos:
        repo = record.get("repo", "")
        lane = record.get("lane", "")
        lines.append(f"| `{repo}` | `{lane}` | expected | expected | expected | planned |")

    lines.extend([
        "",
        "## Notes",
        "",
        "- This report combines policy metadata with optional workflow status evidence when supplied.",
        "- Missing workflow evidence keeps the score policy-derived and should not be used as a final release gate.",
        "- Release readiness should eventually distinguish declared, validated, and released capabilities.",
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
