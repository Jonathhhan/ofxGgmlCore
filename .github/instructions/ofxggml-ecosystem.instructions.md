---
applyTo: "**"
---

# ofxGgml Ecosystem Instructions

- Repository: ofxGgmlCore.
- Lane: backend-neutral runtime base.
- Scope: ggml setup, runtime discovery, shared types, validation, and ecosystem coordination.
- Treat this file as a focused Copilot cloud agent and code review guardrail for ecosystem work.
- For Codex, Copilot, or Hermes integration tasks, start with the Core readiness pass: scripts\check-ecosystem-readiness.ps1.
- If the readiness pass is too broad for the task, generate a planning handoff first: scripts\plan-ecosystem.ps1.
- Work in instruction, documentation, workflow, validation, or planning files before addon source when the task is about the ecosystem or coding agents.
- Do not edit addon runtime behavior unless the user explicitly asks for addon behavior.
- Keep companion changes inside this repository's lane and keep ofxGgmlCore as the shared base.
- Preserve generated artifact hygiene: no binaries, build folders, IDE metadata, model weights, downloaded runtimes, caches, media dumps, or memory indexes.
- Validate before handoff with scripts\release-candidate.ps1; for cross-repo planning also report the Core readiness or planning command used.
## Smoke-Build Target Lifecycle

For ecosystem smoke-build work, stay in the Core control plane first:

1. Plan: scripts\plan-of-smoke-build.ps1
2. Select: scripts\select-smoke-build-target.ps1 -Stage generate-project
3. Handoff: scripts\plan-smoke-build-target-handoff.ps1 -Stage generate-project
4. Preflight: scripts\check-smoke-build-target-preflight.ps1 -Stage generate-project
5. Postflight: scripts\check-smoke-build-target-postflight.ps1 -Stage generate-project

Run projectGenerator only after preflight reports the selected target is ready.
Afterward, run postflight and artifact hygiene before deciding what belongs in
git. Generated openFrameworks project files remain uncommitted unless the
owning addon explicitly tracks them.
