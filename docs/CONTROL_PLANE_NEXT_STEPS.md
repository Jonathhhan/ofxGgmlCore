# Control Plane Next Steps

The workflow-guide rollout is complete across the managed ofxGgml repositories. The next ecosystem work should keep improving the agent control plane before touching addon runtime code.

## P1: Queue Snapshot Maintenance

- Keep `docs\CODING_AGENT_WORK.md` aligned with `scripts\plan-coding-agent-work.bat` after control-plane changes.
- Treat stale generic lane-uplift rows as a regression when the target lane already has a workflow guide.
- Use `scripts\status-family.bat -Json` when another agent needs local inventory summary counts, next commands, and per-repository status before picking a planner; its next commands include compact ecosystem, readiness, and branch-cleanup summary evidence, not branch deletion.
- Use `scripts\status-family.bat -Json -SummaryOnly` when another agent needs compact inventory evidence without full addon records.
- Run `scripts\check-ecosystem-readiness.bat -SkipDoctorTests` before starting broad cross-repository work; it now includes structured agent handoff checks and a deterministic release-readiness planning pass.
- Use `scripts\check-ecosystem-readiness.bat -SkipDoctorTests -Json -SummaryOnly` when another agent needs compact readiness evidence without successful step logs.
- Use `scripts\audit-ecosystem.bat -Strict -Json -SummaryOnly` when another agent needs compact audit blocker evidence without full repository rows.
- Use `scripts\plan-doctor-rollout.bat -Json -SummaryOnly` when another agent needs compact doctor coverage evidence without full script lists.
- Use `scripts\plan-ecosystem.bat -Json` when another agent needs summary counts, planning priorities, guardrails, smoke-build lifecycle commands, and validation commands as structured data.
- Use `scripts\plan-ecosystem.bat -Json -SummaryOnly` when another agent needs compact ecosystem summary evidence without full addon records.
- Use `scripts\plan-coding-agent-work.bat -Json` when another agent needs queue summary data, guardrails, and per-task suggested-file and validation-command arrays.

## P2: Workflow Observability

- Expand workflow status reporting so missing optional workflows, failed required workflows, and stale workflow runs are visible from Core.
- Keep workflow status action summaries readable so required blockers are distinct from optional rollout gaps.
- Use `scripts\fetch-workflow-status.py --stale-days 30` when checking whether latest workflow runs are still fresh enough to trust for release planning.
- Use `scripts\plan-of-smoke-build.bat` before adding real openFrameworks project-generation or compile validation gates.
- Use `scripts\plan-of-smoke-build.bat -Json` when another agent needs smoke-build summary counts, next commands, records, and target queues.
- Treat missing example `addons.make`, owner-addon references, or `ofxGgmlCore` references as blockers before projectGenerator checks.
- Use the smoke-build command plan to choose the next focused example-generation target without committing generated files.
- Prefer the smoke-build target queue order when moving from project generation to generated-project repair or compile validation.
- Use `scripts\select-smoke-build-target.bat -Stage generate-project` when an agent needs the next concrete smoke-build target.
- Use `scripts\select-smoke-build-target.bat -Stage generate-project -Json -SummaryOnly` when another agent needs compact target selection summary counts, next commands, and target summaries.
- Use `scripts\plan-smoke-build-target-handoff.bat -Stage generate-project` before handing a target to Codex, Copilot, or Hermes.
- Use `scripts\plan-smoke-build-target-handoff.bat -Stage generate-project -Json -SummaryOnly` when another agent needs compact handoff summary counts and target summaries without full command and guardrail lists.
- Use `scripts\check-smoke-build-target-preflight.bat -Stage generate-project` before any agent runs projectGenerator.
- Use `scripts\check-smoke-build-target-preflight.bat -Stage generate-project -Json -SummaryOnly` when an agent needs compact readiness summary counts plus gated projectGenerator and postflight commands.
- Use `scripts\check-smoke-build-target-postflight.bat -Repository <addon> -Example <example>` after projectGenerator to inspect generated files and git impact.
- Use `scripts\check-smoke-build-target-postflight.bat -Repository <addon> -Example <example> -Json -SummaryOnly` when an agent needs compact completion summary counts, generated-file counts, review counts, and next validation commands.
- Use `scripts\plan-smoke-build-project-repair.bat -Repository <addon> -Example <example>` when postflight reports missing Visual Studio addon wiring.
- Use `scripts\plan-smoke-build-project-repair.bat -Repository <addon> -Example <example> -Json` when an agent needs repair-state Summary counts, expected addon references, and repair next commands as structured data.
- Use `scripts\plan-smoke-build-project-repair.bat -Repository <addon> -Example <example> -Apply` only after reviewing the dry-run; it updates generated Visual Studio project metadata and should be followed by postflight and artifact hygiene.
- Use `scripts\plan-smoke-build-compile.bat -Stage compile-example` after generated-project postflight is OK to get focused build commands without running them.
- Use `scripts\plan-smoke-build-compile.bat -Repository <addon> -Example <example> -Json` when an agent needs compile-readiness Summary counts, repair status, and next commands.
- Use `scripts\build-smoke-example.bat -Repository <addon> -Example <example>` for generated projects that pass postflight but do not have an addon-owned build wrapper.
- Use `scripts\run-smoke-build-ci.ps1` (or the `smoke-build-ci` GitHub workflow on PRs) to run the full generate-repair-compile control-plane validation loop with all managed examples; its JSON report includes top-level Summary counts for release evidence.
- Keep reusable workflow expectations in `ofxGgmlWorkflows`, and keep caller-addon documentation in Core.
- Prefer reporting gaps over adding new automation until the current workflow state is easy to inspect.

## P2: Branch Cleanup

- Use `scripts\plan-agent-branch-cleanup.bat` after merged Codex, Copilot, or Hermes PRs.
- Keep cleanup planning non-mutating by default; deletion should remain an explicit follow-up.
- Use the generated next-commands section as the review checklist, starting with `-Fetch` before acting on stale local refs.
- Use `scripts\plan-agent-branch-cleanup.bat -Json` when another agent needs machine-readable cleanup commands.
- Use `scripts\plan-agent-branch-cleanup.bat -Json -SummaryOnly` when another agent needs compact cleanup Summary counts, per-repository counts, next commands, and the safety note without branch-level inventory.
- Review the summary counts before acting: scanned repositories, local and remote delete candidates, current branches skipped, local and remote agent branches, and repositories that still carry matching branches.
- Treat `patch-equivalent` cleanup candidates as squash-merged branches whose patch is already represented on the default branch.
- Treat non-zero branch inventory with zero delete candidates as a stale-branch triage signal rather than a delete signal; inspect branch diffs before deciding whether old work is superseded.
- Exclude classified legacy/reference siblings from cleanup suggestions unless they are promoted into the managed set.

## P2: Release Readiness

- Connect release readiness to actual validation evidence: local validation, strict ecosystem audit, readiness check, workflow status, and backend capability evidence.
- Prefer `scripts\plan-release-readiness.bat` for a one-command release evidence pass; it writes to a temporary report path unless `-OutputPath` is supplied.
- Use `scripts\plan-release-readiness.bat -Json` when another agent needs release evidence summary counts, generated report paths, evidence paths, and next commands.
- Use `scripts\plan-release-readiness.bat -Json -SummaryOnly` when another agent needs compact release evidence summaries without generated report paths.
- Use `scripts\plan-release-readiness.bat -SmokeBuildCiReport <path>` when release planning should fold in a downloaded `.smoke-build-ci-report.json` artifact.
- Use `scripts\list-models.bat -Json` when another agent needs model discovery summary counts, existing search directories, and nearby GGUF file metadata before planning model-backed smoke tests.
- Use `scripts\generate-release-readiness-score.py --workflow-status-report <report>` after generating a workflow status report for release planning.
- Use `scripts\generate-release-readiness-score.py --backend-capability-report docs\backend-capability-report.md` when release planning needs backend discovery or runtime-smoke evidence.
- Use `scripts\generate-release-readiness-score.py --smoke-build-ci-report .smoke-build-ci-report.json` when release planning needs generated-project compile evidence.
- `scripts\plan-release-readiness.bat` folds in `docs\backend-capability-report.md` automatically when it exists; use `-SkipBackendCapability` only for policy-only dry runs.
- `scripts\plan-release-readiness.bat` folds in `.smoke-build-ci-report.json` automatically when it exists; use `-SkipSmokeBuildCi` only when intentionally ignoring local smoke-build evidence.
- Keep generated artifacts, local models, build output, and IDE state out of release planning.
- Favor one repository-scoped readiness improvement per PR so agent-authored changes remain reviewable.
