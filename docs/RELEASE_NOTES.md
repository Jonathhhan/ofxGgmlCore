# Release Notes

## Unreleased

- Updated the family map to reflect `v1.0.1` companion releases for Llama, SAM,
  Audio, Music, Diffusion, Vision, Video, RAG, and Agents.
- Added an ecosystem status document with current release heads and next backend
  priorities.
- Made Project Generator metadata explicit and stopped linking SAM3 from Core;
  concrete SAM workflows now belong to `ofxGgmlSam`.

## 1.0.1 - 2026-05-12

- Breaking: renamed the addon/repository line to `ofxGgmlCore` and updated addon
  metadata, example addon dependencies, and first-run documentation.
- Breaking: removed Llama text, chat, embedding examples and llama.cpp runtime
  scripts from Core; those workflows now live in `ofxGgmlLlama`.
- Breaking: `ofxGgmlText.h` now exports only the generic text bridge surface.
  Llama adapter headers moved to `ofxGgmlLlama`.
- Breaking: `ofxGgmlEmbedding.h` no longer exports the transitional
  llama-server embedding adapter; use `ofxGgmlLlama`.
- Kept the existing public C++ `ofxGgml*` symbol and header prefix as a
  compatibility layer during the first companion split.
- Seeded companion addon lanes for Llama, SAM, diffusion, audio, music,
  vision, RAG, agents, and video.
- Added a GitHub Pages-ready `docs/index.html` landing page for the addon
  family.
- Added a GitHub Actions Pages workflow that publishes the `docs` folder.
- Current release candidate validation passed with
  `scripts\validate-local.bat`.

## 1.0.0

- Started the rewritten main line from the frozen `legacy-full` archive.
- Added ggml setup scripts pinned to `v0.11.0`, with CPU, CUDA, Vulkan, Metal,
  OpenCL, auto, and all-backend setup modes.
- Added local validation, generated project repair, launch dry-run, and artifact
  hygiene checks.
- Added the initial Core smoke example.
