# AGENTS.md

This repository is `ofxGgmlCore`, the backend-neutral openFrameworks base addon for the ofxGgml addon family.

Codex should treat this repo as the shared foundation for companion addons such as `ofxGgmlLlama`, `ofxGgmlSam`, `ofxGgmlDiffusion`, `ofxGgmlAudio`, `ofxGgmlMusic`, `ofxGgmlVision`, `ofxGgmlRag`, `ofxGgmlAgents`, and `ofxGgmlVideo`.

## Core contract

Keep Core small, boring, and domain-neutral.

Do:

- maintain shared ggml setup, runtime discovery, request/result primitives, tensor/graph helpers, and lightweight smoke-test examples
- preserve the openFrameworks addon layout and root-level `addon_config.mk`
- keep examples runnable from the openFrameworks project generator
- update docs and scripts when changing public behavior
- keep model-specific workflows in companion addons
- keep generated build outputs, models, caches, and downloaded upstream sources out of git

Do not add:

- model downloads
- llama.cpp server lifecycle
- text/chat/embedding UX
- SAM, diffusion, audio, music, video, RAG, or agent-specific user workflows
- large model files or generated binaries
- hidden global runtime state

## Codex workflow

1. Inspect the existing README, docs, scripts, `addon_config.mk`, and relevant `src/` files first.
2. Propose the smallest implementation plan before editing.
3. Keep diffs focused and reversible.
4. Update examples/docs/scripts together with code changes.
5. Mention companion-addon boundaries explicitly if a request belongs outside Core.
6. Summarize changed files, validation performed, and follow-up work.
