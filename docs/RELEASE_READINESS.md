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
- Core example build validation

Generate the release evidence report before tagging:

```bat
scripts\plan-release-readiness.bat
```

The release evidence report folds in workflow status when network access is
available and `docs\backend-capability-report.md` when it exists. Use
`-SkipWorkflowStatus` only for an offline policy/evidence dry run.

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
- backend capability evidence is present or the release notes explicitly state
  why runtime evidence is unavailable.
- generated binaries, model files, caches, and project files are not staged.
- optional runtimes fail clearly when not installed.
- any new public type has a focused headless test.

`legacy-full` remains the archive branch for the previous broad implementation.
