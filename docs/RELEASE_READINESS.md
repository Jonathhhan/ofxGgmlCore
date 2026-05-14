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

Run:

```bat
scripts\validate-local.bat
```

That command must pass and must not open UI windows or start long-running
servers. It covers:

- headless C++ addon tests
- setup dry-run smoke checks
- generated Visual Studio project repair checks
- simple-example launch dry-run smoke checks
- first-run dry-run checks
- generated-artifact hygiene checks

Example builds are useful release confidence checks when generated project files
exist locally:

```bat
scripts\build-simple-example.bat
```

Companion addon checks should run in their own repositories.

## Tag Gate

Before creating the `1.0.1` tag:

- `main` is clean after validation.
- generated `addon_config.mk` backend-selection edits are either intentionally
  committed or left unstaged as local setup state.
- README setup and validation commands match the actual scripts.
- `docs/CORE_CONTRACT.md` matches the addon boundary.
- generated binaries, model files, caches, and project files are not staged.
- optional runtimes fail clearly when not installed.
- any new public type has a focused headless test.

`legacy-full` remains the archive branch for the previous broad implementation.
