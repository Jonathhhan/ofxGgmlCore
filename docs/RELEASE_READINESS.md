# Release Readiness

This is the pre-tag checklist for `ofxGgmlCore` after the companion-addon split.

## 1.0.1 Scope

`1.0.1` should promise a narrow, dependable Core addon:

- ggml setup pinned to `v0.11.0`
- backend selection through `setup-ggml` and `first-run`
- runtime, tensor, graph, GGUF metadata, and result helpers
- the `ofxGgmlCoreExample` smoke example
- generated Visual Studio project repair helpers
- artifact hygiene for generated dependencies, binaries, models, and projects
- documentation that points model-specific workflows to companion addons

`1.0.1` should not promise llama.cpp tools, text/chat/embedding examples, SAM,
diffusion, audio, music, vision, video, RAG, agents, model downloads, or
product-level GUI workflows.

## Required Checks

Run the full local release candidate pass:

```bat
scripts\release-candidate.bat
```

That command must pass and must not open UI windows or start long-running
servers. It includes:

- headless C++ addon tests
- setup dry-run smoke checks
- generated Visual Studio project repair checks
- Core example launch dry-run smoke checks
- first-run dry-run checks
- generated-artifact hygiene checks
- ecosystem readiness planning
- release-readiness planning
- backend verification planning
- backend runtime verification planning
- Core example build validation

Generate the release evidence report before tagging:

```bat
scripts\plan-release-readiness.bat
```

The release evidence report folds in workflow status when network access is
available, `docs\backend-capability-report.md` when it exists, generated
backend runtime verification planning, and `.smoke-build-ci-report.json` when
present. Use `-SkipWorkflowStatus` only for an offline policy/evidence dry run,
`-SkipBackendRuntimePlan` only when intentionally ignoring runtime-planning
evidence, and pass `-SmokeBuildCiReport <path>` when using a downloaded GitHub
Actions artifact as release evidence.

The JSON mode includes `EvidenceGaps` and `Summary.EvidenceGapCount` so Codex,
Copilot, Hermes, and release automation can tell whether a report is final
release evidence or still waiting on workflow, backend, runtime, or smoke-build
CI inputs.

To fetch the latest uploaded smoke-build CI artifact before planning:

```bat
scripts\fetch-smoke-build-ci-report.bat -Force
scripts\plan-release-readiness.bat
```

In GitHub Actions or another environment with artifact access, a release agent
can do that in one pass:

```bat
scripts\plan-release-readiness.bat -FetchSmokeBuildCiReport
```

The fetch path uses `GITHUB_TOKEN`, `-Token`, or an authenticated local `gh`
session and writes fetched evidence to a temporary file unless
`scripts\fetch-smoke-build-ci-report.bat` is run directly.

Use the strict assertion gate before tagging:

```bat
scripts\assert-release-readiness.bat -SmokeBuildCiReport .smoke-build-ci-report.json
```

That command fails when workflow evidence has required blockers, backend
capability/runtime evidence is missing, smoke-build CI evidence is missing, or
the smoke-build CI report has failed targets or commands.

The `release-gate` GitHub workflow runs the same strict gate on demand and
automatically for `release/**` branches and `v*` tags. It fetches the latest
uploaded smoke-build CI artifact for the selected ref, writes
`.release-readiness-gate.md`, and uploads both gate and smoke-build evidence as
workflow artifacts.

The focused Core example build wrapper remains available when a smaller check is
needed:

```bat
scripts\build-simple-example.bat -Example ofxGgmlCoreExample
```

Companion addon checks should run in their own repositories. Ecosystem-wide
generated-project compile coverage should use the smoke-build control plane and
`smoke-build-ci` workflow rather than committing generated project files.

## Tag Gate

Before creating the `1.0.1` tag:

- `main` is clean after validation.
- generated `addon_config.mk` backend-selection edits are either intentionally
  committed or left unstaged as local setup state.
- README setup and validation commands match the actual scripts.
- `docs/CORE_CONTRACT.md` matches the addon boundary.
- `scripts\plan-release-readiness.bat` has no required workflow blockers.
- `scripts\assert-release-readiness.bat -SmokeBuildCiReport .smoke-build-ci-report.json` passes.
- smoke-build CI evidence reports no failed stages, targets, or commands.
- `scripts\plan-agent-branch-cleanup.bat -Json -SummaryOnly` has been reviewed
  so release handoffs see stale Codex/Copilot/Hermes branch counts without
  deleting branches automatically.
- backend capability evidence is present or the release notes explicitly state
  why runtime evidence is unavailable.
- `scripts\plan-backend-runtime-verification.bat -Json -SummaryOnly` reports
  managed runtime-smoke entrypoints as `available-and-validated` before release.
- generated binaries, model files, caches, and project files are not staged.
- optional runtimes fail clearly when not installed.
- any new public type has a focused headless test.

`legacy-full` remains the archive branch for the previous broad implementation.
