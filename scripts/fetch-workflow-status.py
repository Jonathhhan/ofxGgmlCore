#!/usr/bin/env python3

import argparse
import datetime as dt
import json
import os
import shutil
import subprocess
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ecosystem.json"
OUTPUT = ROOT / "docs" / "workflow-status-report.md"

WORKFLOWS = [
    {"name": "addon-hygiene.yml", "required": True},
    {"name": "coding-agent-instructions.yml", "required": True},
    {"name": "metadata-validation.yml", "required": True},
    {"name": "multi-platform-smoke.yml", "required": True},
    {"name": "release-check.yml", "required": False},
    {"name": "baseline-compatibility.yml", "required": False},
    {"name": "release-gate.yml", "required": False, "repos": ["Jonathhhan/ofxGgmlCore"]},
]

BLOCKING_CONCLUSIONS = {
    "action_required",
    "cancelled",
    "failure",
    "startup_failure",
    "timed_out",
}


def gh_api_json(url):
    gh = shutil.which("gh")
    if not gh:
        raise RuntimeError("gh executable was not found")
    parsed = urllib.parse.urlsplit(url)
    endpoint = parsed.path.lstrip("/")
    if parsed.query:
        endpoint = f"{endpoint}?{parsed.query}"
    result = subprocess.run(
        [gh, "api", endpoint],
        check=True,
        capture_output=True,
        text=True,
        timeout=20,
    )
    return json.loads(result.stdout)


def github_json(url):
    if not os.environ.get("GITHUB_TOKEN") and shutil.which("gh"):
        return gh_api_json(url)

    headers = {"Accept": "application/vnd.github+json"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        if exc.code in {403, 429} and shutil.which("gh"):
            return gh_api_json(url)
        raise


def github_access_mode():
    if os.environ.get("GITHUB_TOKEN"):
        return "GITHUB_TOKEN"
    if shutil.which("gh"):
        return "authenticated GitHub CLI (`gh`) if available"
    return "unauthenticated public GitHub API"


def count_unavailable_http(records, code):
    needle = f"unavailable: HTTP {code}"
    return sum(1 for record in records if record["status"].get("summary") == needle)


def repos_from_manifest(ecosystem):
    core = ecosystem.get("core", {}).get("repo")
    if core:
        yield core
    for addon in ecosystem.get("addons", []):
        repo = addon.get("repo")
        if repo:
            yield repo


def workflow_specs_for_repo(repo):
    for workflow_spec in WORKFLOWS:
        repos = workflow_spec.get("repos")
        if repos and repo not in repos:
            continue
        yield workflow_spec


def latest_workflow_status(repo, workflow):
    url = f"https://api.github.com/repos/{repo}/actions/workflows/{workflow}/runs?per_page=1"
    try:
        data = github_json(url)
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return {
                "state": "missing",
                "summary": "missing workflow",
                "url": "",
            }
        return {
            "state": "unavailable",
            "summary": f"unavailable: HTTP {exc.code}",
            "url": "",
        }
    except Exception as exc:
        return {
            "state": "unavailable",
            "summary": f"unavailable: {exc.__class__.__name__}",
            "url": "",
        }

    runs = data.get("workflow_runs", [])
    if not runs:
        return {
            "state": "no-runs",
            "summary": "no runs",
            "url": "",
        }
    run = runs[0]
    conclusion = run.get("conclusion") or run.get("status") or "unknown"
    return {
        "state": conclusion,
        "summary": conclusion,
        "url": run.get("html_url", ""),
        "updated_at": run.get("updated_at", ""),
    }


def parse_github_time(value):
    if not value:
        return None
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def workflow_issue(record):
    status = record["status"]
    state = status["state"]
    if state in BLOCKING_CONCLUSIONS:
        return f"latest run {status['summary']}"
    if state == "missing":
        return "workflow file missing"
    if state == "no-runs":
        return "workflow has no runs"
    if state == "unavailable":
        return status["summary"]
    if status.get("stale", False):
        age_days = status.get("age_days")
        if age_days is None:
            return "latest run is stale"
        return f"latest run is stale ({age_days}d)"
    return ""


def workflow_issue_line(record):
    issue = workflow_issue(record)
    if not issue:
        return ""
    return f"- `{record['repo']}` / `{record['workflow']}`: {issue}."


def parse_args():
    parser = argparse.ArgumentParser(description="Fetch latest GitHub Actions status for the ofxGgml ecosystem.")
    parser.add_argument("--strict", action="store_true", help="Exit nonzero when required workflows are missing, unavailable, have no runs, or last ended in a blocking conclusion.")
    parser.add_argument("--output", default=str(OUTPUT), help="Markdown report path.")
    parser.add_argument("--stale-days", type=int, default=30, help="Mark latest workflow runs older than this many days as stale.")
    return parser.parse_args()


def main():
    args = parse_args()
    ecosystem = json.loads(MANIFEST.read_text(encoding="utf-8"))
    records = []
    counts = {
        "success": 0,
        "blocking": 0,
        "missing_required": 0,
        "missing_optional": 0,
        "no_runs_required": 0,
        "no_runs_optional": 0,
        "unavailable_required": 0,
        "unavailable_optional": 0,
        "stale_required": 0,
        "stale_optional": 0,
    }
    now = dt.datetime.now(dt.timezone.utc)

    for repo in repos_from_manifest(ecosystem):
        for workflow_spec in workflow_specs_for_repo(repo):
            workflow = workflow_spec["name"]
            required = workflow_spec["required"]
            status = latest_workflow_status(repo, workflow)
            state = status["state"]
            updated_at = parse_github_time(status.get("updated_at", ""))
            stale = False
            if updated_at is not None:
                age_days = (now - updated_at).days
                stale = age_days > args.stale_days
                status["age_days"] = age_days
                if stale:
                    counts["stale_required" if required else "stale_optional"] += 1
            else:
                status["age_days"] = None
            status["stale"] = stale

            if state == "success":
                counts["success"] += 1
            elif state in BLOCKING_CONCLUSIONS:
                counts["blocking"] += 1
            elif state == "missing":
                counts["missing_required" if required else "missing_optional"] += 1
            elif state == "no-runs":
                counts["no_runs_required" if required else "no_runs_optional"] += 1
            elif state == "unavailable":
                counts["unavailable_required" if required else "unavailable_optional"] += 1

            records.append({
                "repo": repo,
                "workflow": workflow,
                "required": required,
                "status": status,
            })

    strict_failures = [
        record for record in records
        if record["required"] and (
            record["status"]["state"] in BLOCKING_CONCLUSIONS or
            record["status"]["state"] in {"missing", "no-runs", "unavailable"} or
            record["status"].get("stale", False)
        )
    ]
    optional_gaps = [
        record for record in records
        if not record["required"] and workflow_issue(record)
    ]
    rate_limited_count = count_unavailable_http(records, 429)

    lines = [
        "# Workflow Status Report",
        "",
        "This report fetches latest GitHub Actions workflow status where available.",
        "It is observational by default; use `--strict` to make required workflow gaps fail.",
        "",
        "## Summary",
        "",
        f"- Successful latest runs: `{counts['success']}`",
        f"- Blocking latest runs: `{counts['blocking']}`",
        f"- Missing required workflows: `{counts['missing_required']}`",
        f"- Missing optional workflows: `{counts['missing_optional']}`",
        f"- Required workflows with no runs: `{counts['no_runs_required']}`",
        f"- Optional workflows with no runs: `{counts['no_runs_optional']}`",
        f"- Unavailable required statuses: `{counts['unavailable_required']}`",
        f"- Unavailable optional statuses: `{counts['unavailable_optional']}`",
        f"- Stale required workflows: `{counts['stale_required']}`",
        f"- Stale optional workflows: `{counts['stale_optional']}`",
        f"- Stale threshold: `{args.stale_days}` days",
        f"- GitHub access mode: `{github_access_mode()}`",
        "",
        "## Action Required",
        "",
        "### Required Workflow Blockers",
        "",
    ]
    if strict_failures:
        lines.extend(workflow_issue_line(record) for record in strict_failures)
    else:
        lines.append("- None.")

    lines.extend([
        "",
        "### Optional Workflow Rollout Gaps",
        "",
    ])
    if optional_gaps:
        lines.extend(workflow_issue_line(record) for record in optional_gaps)
    else:
        lines.append("- None.")

    lines.extend([
        "",
        "## Workflows",
        "",
        "| Repository | Workflow | Required | Latest status | Age | Run |",
        "| --- | --- | --- | --- | ---: | --- |",
    ])
    for record in records:
        required = "yes" if record["required"] else "optional"
        status = record["status"]
        url = status["url"]
        run = f"[run]({url})" if url else "-"
        age_days = status.get("age_days")
        age = "-" if age_days is None else f"{age_days}d"
        if status.get("stale", False):
            age = f"{age} stale"
        lines.append(f"| `{record['repo']}` | `{record['workflow']}` | {required} | {status['summary']} | {age} | {run} |")

    lines.extend([
        "",
        "## Notes",
        "",
        f"- Current GitHub access mode: `{github_access_mode()}`.",
        "- Set `GITHUB_TOKEN` for higher API limits and private-repo access.",
        "- When `GITHUB_TOKEN` is absent, an authenticated GitHub CLI (`gh`) is used automatically if available.",
        "- HTTP 429 means GitHub rate limited workflow-status evidence; rerun with `GITHUB_TOKEN` or authenticated `gh` before using this report as a strict release gate.",
        "- Missing optional workflows are rollout gaps, not command failures.",
        "- Repository-scoped workflow expectations only apply to the listed repositories.",
        "- Stale workflow runs are visible by default and fail required workflows only in `--strict` mode.",
        "- Release gating should consume this report after required workflow coverage is complete.",
    ])
    if rate_limited_count > 0:
        lines.extend([
            f"- Rate-limit diagnosis: `{rate_limited_count}` workflow status request(s) returned HTTP 429.",
            "- Release gate action: provide authenticated GitHub access, regenerate workflow-status evidence, then rerun `scripts\\assert-release-readiness.bat`.",
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

    if args.strict and strict_failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
