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
- non-mutating generated-project repair planning

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
scripts\plan-release-readiness.bat -SkipWorkflowStatus
```

The readiness pass currently verifies:

- workflow planning guides are present across managed repositories
- generated agent instructions are current
- strict ecosystem audit passes
- ecosystem planning handoff runs
- coding-agent work queue generation runs
- openFrameworks smoke-build rollout planning runs
- smoke-build planning verifies root-level example addon metadata before projectGenerator rollout
- smoke-build planning reports projectGenerator command candidates and existing generated project files
- smoke-build planning orders next targets by metadata repair, project generation, then generated-project verification
- smoke-build target selection returns the next filtered target without mutating addon worktrees
- smoke-build target handoff emits validation, artifact-hygiene, and machine-readable next commands for the selected target
- smoke-build preflight checks projectGenerator, metadata, repository cleanliness, generated-project state, and emits readiness-gated next commands
- smoke-build postflight reports generated project files, Visual Studio addon wiring, git impact, completion/review counts, and next commands after target work
- smoke-build project repair planning reports missing Visual Studio addon references and next commands for regeneration, postflight, and hygiene checks
- release-readiness planning runs without requiring live workflow access
- release-readiness evidence preserves workflow required blockers and optional rollout gaps
- doctor rollout planning runs
- merged agent branch cleanup planning runs and emits explicit next commands in Markdown and JSON

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
- reports projectGenerator command candidates without generating project files
- ranks next smoke-build targets without mutating companion addon worktrees
- validates cross-platform workflow execution
- is visible in the workflow status report with latest-run age and stale-run markers
- is summarized in workflow-status reports as required blockers and optional rollout gaps
- detects the embedded command-line projectGenerator before the GUI wrapper on Windows
- detects generated Visual Studio project files that are present but missing expected addon wiring
- plans non-mutating repair steps for missing Visual Studio addon wiring
- does not yet compile openFrameworks examples
- does not yet complete Visual Studio generated-project verification after projectGenerator crashes during addon processing
- does not yet validate CUDA/Metal/Vulkan runtimes
- does not yet validate runtime inference

## Next operational milestones

- real openFrameworks smoke builds
- example project generation checks
- backend runtime verification
- inference smoke tests
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
