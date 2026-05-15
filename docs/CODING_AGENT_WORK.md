# ofxGgml Coding Agent Work Queue

Generated from local ecosystem status. This queue is intended for Codex, GitHub Copilot, Hermes Agent, and similar coding assistants.

## Snapshot

| Metric | Count |
| --- | ---: |
| Managed repositories | 11 |
| Ready managed repositories | 11 |
| Workflow guides detected | 11 |
| Detected reference repositories | 7 |
| Proposed tasks | 1 |

## Queue

| Priority | Repository | Lane | Category | Task | Suggested files | Validation |
| --- | --- | --- | --- | --- | --- | --- |
| P1 | `ofxGgmlCore` | `backend-neutral runtime base` | control-plane | Keep the ecosystem control plane current by refreshing queue, readiness, smoke-build, workflow action summaries, and release-evidence docs. | `README.md; docs/CODING_AGENT_WORK.md; docs/CONTROL_PLANE_NEXT_STEPS.md; docs/operational-validation-status.md; docs/of-smoke-build-strategy.md; docs/release-gating-strategy.md; scripts/status-family.ps1; scripts/test-family-status.ps1; scripts/audit-ecosystem.ps1; scripts/test-ecosystem-audit.ps1; scripts/plan-ecosystem.ps1; scripts/test-ecosystem-agent.ps1; scripts/plan-doctor-rollout.ps1; scripts/test-doctor-rollout-plan.ps1; scripts/check-ecosystem-readiness.ps1; scripts/validate-local.ps1; scripts/plan-of-smoke-build.ps1; scripts/select-smoke-build-target.ps1; scripts/plan-smoke-build-target-handoff.ps1; scripts/check-smoke-build-target-preflight.ps1; scripts/check-smoke-build-target-postflight.ps1; scripts/plan-smoke-build-project-repair.ps1; scripts/plan-smoke-build-compile.ps1; scripts/build-smoke-example.ps1; scripts/run-smoke-build-ci.bat; scripts/run-smoke-build-ci.ps1; scripts/run-smoke-build-ci.sh; scripts/smoke-build-ci-report.ps1; scripts/test-smoke-build-ci-report.ps1; scripts/fetch-smoke-build-ci-report.ps1; scripts/test-fetch-smoke-build-ci-report.ps1; scripts/assert-release-readiness.ps1; scripts/test-release-readiness-gate.ps1; scripts/plan-agent-branch-cleanup.ps1; scripts/test-agent-branch-cleanup.ps1; scripts/plan-backend-runtime-verification.ps1; scripts/test-backend-runtime-verification-plan.ps1; scripts/fetch-workflow-status.bat; scripts/fetch-workflow-status.py; scripts/fetch-workflow-status.sh; scripts/test-workflow-status-report.ps1; scripts/generate-workflow-status-plan.bat; scripts/generate-workflow-status-plan.py; scripts/generate-workflow-status-plan.sh; scripts/test-workflow-status-plan.ps1; scripts/generate-release-readiness-score.py; scripts/plan-release-readiness.ps1` | `scripts/check-ecosystem-readiness.bat -SkipDoctorTests; scripts/check-ecosystem-readiness.bat -SkipDoctorTests -Json -SummaryOnly; scripts/status-family.bat -Json -SummaryOnly; scripts/test-family-status.ps1; scripts/audit-ecosystem.bat -Strict -Json -SummaryOnly; scripts/test-ecosystem-audit.ps1; scripts/plan-doctor-rollout.bat -Json -SummaryOnly; scripts/test-doctor-rollout-plan.ps1; scripts/plan-backend-runtime-verification.bat -Json -SummaryOnly; scripts/test-backend-runtime-verification-plan.ps1; scripts/plan-ecosystem.bat -Json -SummaryOnly; scripts/plan-release-readiness.bat -Json -SummaryOnly; scripts/test-workflow-status-report.ps1; scripts/test-workflow-status-plan.ps1; scripts/test-release-readiness-score.ps1; scripts/test-release-readiness-plan.ps1; scripts/test-release-readiness-gate.ps1; scripts/test-smoke-build-ci-report.ps1; scripts/test-fetch-smoke-build-ci-report.ps1; scripts/test-agent-branch-cleanup.ps1; scripts/plan-agent-branch-cleanup.bat -Json -SummaryOnly; scripts/plan-smoke-build-target-handoff.bat -Stage generate-project -Json -SummaryOnly; scripts/check-smoke-build-target-preflight.bat -Stage generate-project -Json -SummaryOnly; scripts/check-smoke-build-target-postflight.bat -Stage generate-project -Json -SummaryOnly; scripts/plan-smoke-build-project-repair.bat -Stage verify-generated-project; scripts/plan-smoke-build-compile.bat -Stage compile-example; scripts/build-smoke-example.bat -Repository ofxGgmlSam -Example ofxGgmlSamPointExample; scripts/run-smoke-build-ci.bat -CloneAddonRepos -TargetsPerStage 0` |

## Auto-Detected Completed Planning Guides

| Repository | Guide |
| --- | --- |
| `ofxGgmlAgents` | `docs\AGENT_WORKFLOWS.md` |
| `ofxGgmlAudio` | `docs\AUDIO_WORKFLOWS.md` |
| `ofxGgmlCore` | `docs\ECOSYSTEM_AGENT.md` |
| `ofxGgmlDiffusion` | `docs\DIFFUSION_WORKFLOWS.md` |
| `ofxGgmlLlama` | `docs\LLAMA_WORKFLOWS.md` |
| `ofxGgmlMusic` | `docs\MUSIC_WORKFLOWS.md` |
| `ofxGgmlRag` | `docs\RAG_WORKFLOWS.md` |
| `ofxGgmlSam` | `docs\SAM_WORKFLOWS.md` |
| `ofxGgmlVideo` | `docs\VIDEO_WORKFLOWS.md` |
| `ofxGgmlVision` | `docs\VISION_WORKFLOWS.md` |
| `ofxGgmlWorkflows` | `docs\workflow-adoption.md` |

## Guardrails

- Work on planning, instructions, workflow, validation, and documentation first.
- Do not edit addon runtime/source behavior unless the user explicitly asks for that repository and behavior.
- Keep classified reference repositories out of generated automation unless they are intentionally promoted.
- Prefer one small repository-scoped pull request over broad cross-repo edits.
- Run the suggested validation before pushing.
