# Hermes Project Context

This repository is part of the ofxGgml openFrameworks addon ecosystem.

## Repository

- Addon: ofxGgmlCore
- Lane: backend-neutral runtime base
- Scope: ggml setup, runtime discovery, shared types, validation, and ecosystem coordination

## Hermes Agent Rules

- Treat this file as project context for Hermes Agent.
- Read README.md, addon_config.mk, docs, scripts, and tests before changing behavior.
- Keep changes inside this repository's lane unless the task explicitly requires cross-repo coordination.
- For ecosystem improvement work, create or update a plan before touching addon source.
- Keep ofxGgmlCore as the shared base; companion addons may depend on Core, but Core must not depend on companions.
- Do not commit generated binaries, model files, downloaded runtimes, build folders, IDE metadata, memory indexes, caches, or media dumps.
- Prefer small, validated changes over broad refactors.
- Validation before handoff: scripts\release-candidate.ps1.

## Planning Workflow

- Use scripts\status-family.ps1 and scripts\plan-ecosystem.ps1 from ofxGgmlCore for cross-repo planning.
- Classify each task as documentation, automation, validation, or addon-code work.
- Work in the agent layer first when the goal is better Codex, Copilot, or Hermes planning.
- Touch addon source only when the user explicitly asks for addon behavior.
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

## Ecosystem Split

Model-specific workflows belong in companion addons. Shared helpers should move
to ofxGgmlCore only when they are stable, domain-neutral, dependency-light, and
covered by focused tests.
