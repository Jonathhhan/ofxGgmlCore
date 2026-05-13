# GitHub Copilot Repository Instructions

ofxGgmlCore is part of the ofxGgml openFrameworks addon ecosystem.

- Scope: ggml setup, runtime discovery, shared types, validation, and ecosystem coordination
- Keep changes inside this addon's lane unless a task explicitly asks for a cross-addon update.
- For ecosystem planning tasks, prefer instruction, documentation, workflow, and validation changes before addon source changes.
- Use ofxGgmlCore for shared runtime primitives and keep companion workflows out of Core.
- Avoid committing generated outputs, local models, build directories, IDE metadata, downloaded runtimes, caches, or media dumps.
- Add or update headless tests for public helper behavior.
- Validation before handoff: scripts\release-candidate.ps1.
- Keep explanations concise and include the files and checks that matter.
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
