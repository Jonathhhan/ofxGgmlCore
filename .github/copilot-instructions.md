# Repository coding instructions

This repository is `ofxGgmlCore`, the backend-neutral openFrameworks base addon for the ofxGgml addon family.

## Architectural boundaries

Keep Core small, reusable, and model-agnostic. Core may contain shared ggml setup, runtime discovery, tensor/graph helpers, request/result primitives, lightweight diagnostics, validation scripts, and smoke-test examples.

Do not add model-specific workflows here. Text/chat/embeddings belong in `ofxGgmlLlama`; Whisper/audio in `ofxGgmlAudio`; segmentation in `ofxGgmlSam`; diffusion/image generation in `ofxGgmlDiffusion`; CLIP/vision in `ofxGgmlVision`; retrieval in `ofxGgmlRag`; planning/tool loops in `ofxGgmlAgents`; video workflows in `ofxGgmlVideo`; music workflows in `ofxGgmlMusic`.

## openFrameworks addon rules

- Preserve the standard addon layout: `addon_config.mk`, `src/`, `examples/`, `scripts/`, and `docs/`.
- Keep examples projectGenerator-friendly.
- Do not commit large models, generated projects, build folders, binaries, or downloaded upstream source caches.
- Keep `addon_config.mk` source/include lists aligned with any moved or added files.
- Preserve platform sections for Visual Studio, Linux, and macOS.
- Avoid hardcoded absolute local paths.

## C++ rules

- Prefer C++17-compatible code.
- Keep headers lightweight and APIs explicit.
- Avoid hidden global state.
- Prefer small request/result structs for shared primitives.
- Avoid blocking the openFrameworks update/draw loop unless the example intentionally demonstrates a minimal synchronous path.

## Script and validation rules

When editing scripts, maintain parity between macOS/Linux shell scripts and Windows batch/PowerShell scripts where practical.

Before completing a change, run the smallest relevant subset when possible:

```sh
./scripts/doctor.sh
./scripts/validate-local.sh
./scripts/build-simple-example.sh
./scripts/run-simple-example.sh -Build
```

Windows equivalents:

```bat
scripts\\doctor.bat
scripts\\validate-local.bat
scripts\\build-simple-example.bat
```

If checks cannot be run, state exactly why.
