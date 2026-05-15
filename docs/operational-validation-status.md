# Operational Validation Status

## Current operational layer

The ecosystem currently provides:

- centralized reusable workflows
- metadata validation
- baseline compatibility checks
- cross-repo metadata reconciliation
- live workflow observability scaffolding
- actionable workflow blocker and rollout-gap summaries
- stale workflow run reporting
- structured JSON handoff checks for Codex, GitHub Copilot, and Hermes
- coding-agent work queue generation
- workflow guide coverage detection
- multi-platform smoke-build scaffolding
- root-level example `addons.make` readiness planning
- projectGenerator command planning for managed root-level examples
- prioritized smoke-build target queue generation
- one-command smoke-build target selection
- smoke-build target handoff generation
- non-mutating smoke-build target preflight checks
- non-mutating smoke-build target postflight reports
- dry-run and explicit-apply generated-project repair planning
- non-mutating focused compile-target planning
- generic focused smoke-example build handoff for generated projects that pass postflight
- backend runtime smoke execution through the reusable `backend-runtime-check` workflow
- CPU backend initialization plus lightweight ggml graph compute/readback smoke on Windows and Ubuntu CI
- lane-owned runtime-smoke entrypoints across all managed runtime lanes
- backend runtime verification planning that reports managed runtime lanes as `available-and-validated`

## Current agent readiness

The Codex, GitHub Copilot, and Hermes planning layer is active. From
`ofxGgmlCore`, agents can run:

```powershell
scripts\check-ecosystem-readiness.bat -SkipDoctorTests
scripts\audit-ecosystem.bat -Strict
scripts\plan-ecosystem.bat
scripts\plan-coding-agent-work.bat
scripts\plan-of-smoke-build.bat
scripts\select-smoke-build-target.bat -Stage generate-project
scripts\plan-smoke-build-target-handoff.bat -Stage generate-project
scripts\check-smoke-build-target-preflight.bat -Stage generate-project
scripts\check-smoke-build-target-postflight.bat -Stage generate-project
scripts\plan-smoke-build-project-repair.bat -Stage verify-generated-project
scripts\plan-smoke-build-compile.bat -Stage compile-example
scripts\build-smoke-example.bat -Repository ofxGgmlSam -Example ofxGgmlSamPointExample
scripts\plan-backend-runtime-verification.bat -Json -SummaryOnly
scripts\run-smoke-build-ci.ps1 -CloneAddonRepos -TargetsPerStage 0
scripts\plan-release-readiness.bat -Json -SummaryOnly
scripts\build-runtime-smoke.bat -Backend cpu
```

The readiness pass currently verifies:

- workflow planning guides are present across managed repositories
- generated agent instructions are current
- strict ecosystem audit passes
- ecosystem planning handoff runs
- structured ecosystem planning JSON handoff runs
- coding-agent work queue generation runs
- structured coding-agent work queue JSON handoff runs
- openFrameworks smoke-build rollout planning runs
- smoke-build planning verifies root-level example addon metadata before projectGenerator rollout
- smoke-build planning reports projectGenerator command candidates and existing generated project files
- smoke-build planning orders next targets by metadata repair, project generation, then generated-project verification
- smoke-build target selection returns the next filtered target without mutating addon worktrees
- smoke-build target handoff emits validation, artifact-hygiene, and machine-readable next commands for the selected target
- smoke-build preflight checks projectGenerator, metadata, repository cleanliness, generated-project state, and emits readiness-gated next commands
- smoke-build postflight reports generated project files, Visual Studio addon wiring, git impact, completion/review counts, and next commands after target work
- smoke-build project repair planning reports missing Visual Studio addon references, supports explicit generated-metadata repair with `-Apply`, and emits next commands for postflight and hygiene checks
- smoke-build compile planning emits focused build commands only after generated-project postflight is complete, using addon-owned build scripts when present and the Core generic smoke builder otherwise
- smoke-build CI writes a JSON report with top-level Summary counts for stages, targets, commands, and failures
- release-readiness planning runs without requiring live workflow access
- release-readiness evidence preserves workflow required blockers and optional rollout gaps
- release-readiness evidence folds in backend capability reports when available
- release-readiness evidence folds in smoke-build CI Summary counts when available
- backend-runtime-check caller workflow runs automatically for relevant Core runtime, ggml setup, metadata, and workflow changes
- CPU backend runtime smoke initializes ggml and executes a lightweight graph compute/readback check in CI
- backend runtime verification reports `ofxGgmlLlama`, `ofxGgmlSam`, `ofxGgmlAudio`, `ofxGgmlMusic`, `ofxGgmlDiffusion`, `ofxGgmlVision`, `ofxGgmlVideo`, `ofxGgmlRag`, and `ofxGgmlAgents` as `available-and-validated`
- release-readiness planning identifies missing smoke-build CI report evidence when `.smoke-build-ci-report.json` is absent
- doctor rollout planning runs
- merged agent branch cleanup planning runs and emits explicit next commands in Markdown, full JSON, and compact summary JSON for readiness handoffs

The current queue reports all managed repositories as ready, detects planning
guides for all 11 managed repositories, and suppresses stale generic lane-uplift
tasks once those guides exist. The remaining default task is Core control-plane
maintenance before any addon runtime/source changes.

## Current smoke-build coverage

### Repositories using reusable multi-platform smoke workflow

- ofxGgmlCore
- ofxGgmlLlama
- ofxGgmlAudio
- ofxGgmlVision
- ofxGgmlDiffusion
- ofxGgmlSam
- ofxGgmlMusic
- ofxGgmlRag
- ofxGgmlAgents
- ofxGgmlVideo

## Current limitations

The current smoke-build workflow:

- validates basic repository structure
- plans projectGenerator readiness from root-level example `addons.make` metadata
- plans projectGenerator command candidates in non-mutating mode for CI stage entry
- ranks next smoke-build targets without mutating companion addon worktrees
- executes all generate-repair-compile stage targets per CI run when `run-smoke-build-ci` is configured for full pass
- validates cross-platform workflow execution
- is visible in the workflow status report with latest-run age and stale-run markers
- is summarized in workflow-status reports as required blockers and optional rollout gaps
- detects the embedded command-line projectGenerator before the GUI wrapper on Windows
- detects generated Visual Studio project files that are present but missing expected addon wiring
- plans and explicitly applies generated Visual Studio addon-wiring repair steps
- plans focused compile targets for generated projects that pass postflight
- provides a generic local focused compile command for generated projects that do not own addon-local build scripts
- locally generated, repaired, and postflight-verified Visual Studio projects for all 14 managed addon examples while keeping owning addon worktrees clean
- locally built all 14 managed addon examples on Windows Release x64 with 0 errors
- compiles generated managed examples in CI on pull_request via the new `smoke-build-ci` workflow (Windows Release x64)
- does not yet eliminate the Windows projectGenerator addon-processing crash; generated-project repair currently compensates for it
- validates CPU backend runtime initialization and lightweight graph smoke in CI for Core runtime changes
- plans backend runtime verification evidence from Core with compact CPU/CUDA/Metal/Vulkan declaration, model-path, example-build, runtime-smoke, and reference-lane readiness summaries
- uses lane-owned runtime-smoke evidence across all managed runtime lanes as release-readiness handoff material
- still needs a smoke-build CI report artifact before generated-project compile evidence can be treated as release CI truth
- does not yet validate CUDA/Metal/Vulkan runtimes in CI
- does not yet validate model-backed runtime inference

## Next operational milestones

- Linux and macOS real openFrameworks smoke-build coverage (generation + compile)
- generate and persist smoke-build CI evidence for release readiness with `scripts\run-smoke-build-ci.ps1 -CloneAddonRepos -TargetsPerStage 0`
- keep lane-owned runtime-smoke evidence fresh as model-backed and GPU-backed lanes mature
- GPU backend runtime verification from suitable runners
- model-backed inference smoke tests
- release gating from CI truth
- compatibility enforcement from actual builds
- recurring review of the generated coding-agent work queue
- periodic review that each managed lane still exposes an agent workflow guide

## Long-term direction

The ecosystem is evolving toward:

- live operational observability
- self-validating release trains
- metadata-backed compatibility enforcement
- autonomous ecosystem coordination
