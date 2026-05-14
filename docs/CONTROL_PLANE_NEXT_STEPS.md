# Control Plane Next Steps

The workflow-guide rollout is complete across the managed ofxGgml repositories. The next ecosystem work should keep improving the agent control plane before touching addon runtime code.

## P1: Queue Snapshot Maintenance

- Keep `docs\CODING_AGENT_WORK.md` aligned with `scripts\plan-coding-agent-work.bat` after control-plane changes.
- Treat stale generic lane-uplift rows as a regression when the target lane already has a workflow guide.
- Run `scripts\check-ecosystem-readiness.bat -SkipDoctorTests` before starting broad cross-repository work; it now includes a deterministic release-readiness planning pass.

## P2: Workflow Observability

- Expand workflow status reporting so missing optional workflows, failed required workflows, and stale workflow runs are visible from Core.
- Use `scripts\fetch-workflow-status.py --stale-days 30` when checking whether latest workflow runs are still fresh enough to trust for release planning.
- Use `scripts\plan-of-smoke-build.bat` before adding real openFrameworks project-generation or compile validation gates.
- Keep reusable workflow expectations in `ofxGgmlWorkflows`, and keep caller-addon documentation in Core.
- Prefer reporting gaps over adding new automation until the current workflow state is easy to inspect.

## P2: Branch Cleanup

- Use `scripts\plan-agent-branch-cleanup.bat` after merged Codex, Copilot, or Hermes PRs.
- Keep cleanup planning non-mutating by default; deletion should remain an explicit follow-up.
- Review the summary counts before acting: scanned repositories, local and remote delete candidates, and current branches skipped.
- Exclude classified legacy/reference siblings from cleanup suggestions unless they are promoted into the managed set.

## P2: Release Readiness

- Connect release readiness to actual validation evidence: local validation, strict ecosystem audit, readiness check, and workflow status.
- Prefer `scripts\plan-release-readiness.bat` for a one-command release evidence pass.
- Use `scripts\generate-release-readiness-score.py --workflow-status-report <report>` after generating a workflow status report for release planning.
- Keep generated artifacts, local models, build output, and IDE state out of release planning.
- Favor one repository-scoped readiness improvement per PR so agent-authored changes remain reviewable.
