# Codex Repository Instructions

This repository is part of the ofxGgml openFrameworks addon ecosystem.

## Addon Scope

- Addon: ofxGgmlCore
- Lane: backend-neutral runtime base
- Role: ggml setup, runtime discovery, shared types, validation, and ecosystem coordination

## Working Rules

- Read the existing code and docs before changing behavior.
- Keep edits scoped to this addon's lane and preserve the companion-addon split.
- Start with an ecosystem plan when a task asks for cross-repo improvement or planning.
- Keep ofxGgmlCore as the shared base; do not add reverse dependencies from Core to companion addons.
- Do not commit generated project files, binaries, model weights, downloaded runtimes, sample media dumps, memory indexes, or caches.
- Prefer focused tests and local validation over broad refactors.
- Preserve openFrameworks-style public names and document intentional breaking changes.
## Core Contract

Keep Core small, boring, reusable, and model-agnostic.

Core may contain shared ggml setup, runtime discovery, tensor/graph helpers,
request/result primitives, lightweight diagnostics, validation scripts, and
smoke-test examples.

Do not add model-specific workflows here. Text/chat/embeddings belong in
ofxGgmlLlama; audio and Whisper workflows in ofxGgmlAudio; segmentation in
ofxGgmlSam; diffusion/image generation in ofxGgmlDiffusion; vision in
ofxGgmlVision; retrieval in ofxGgmlRag; planning/tool loops in ofxGgmlAgents;
video in ofxGgmlVideo; and music workflows in ofxGgmlMusic.

## openFrameworks Addon Rules

- Preserve the standard addon layout, root-level addon_config.mk, src, scripts, docs, and examples.
- Keep examples projectGenerator-friendly.
- Avoid hardcoded absolute local paths.
- Keep addon_config.mk source/include lists aligned with moved or added files.

## Validation

Validation before handoff: scripts\release-candidate.ps1.

For ecosystem planning work, run scripts\plan-ecosystem.ps1 from ofxGgmlCore
before proposing addon-code changes.

## Ecosystem Notes

Model-specific UX belongs in companion addons. Shared code should move down into
ofxGgmlCore only after it is stable, domain-neutral, dependency-light, and
covered by focused tests.
