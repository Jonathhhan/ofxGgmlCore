# Backend Verification Plan

This document defines how declared backend support should become validated backend support.

## Verification levels

| Level | Meaning |
| --- | --- |
| declared | Listed in `ofxggml-addon.json` |
| build-checked | CI compiled code paths for the backend |
| runtime-checked | Backend initialization succeeds in CI or local validation |
| graph-smoke-checked | A lightweight ggml graph compute/readback smoke test succeeds |
| inference-checked | A minimal model/inference smoke test succeeds |

## Repository backend validation targets

| Repository | Lane | Backend validation target | Current status |
| --- | --- | --- | --- |
| `Jonathhhan/ofxGgmlCore` | `core` | `backend-runtime-check` CPU runtime smoke | runtime-checked and graph-smoke-checked on CI |
| `Jonathhhan/ofxGgmlLlama` | `text-chat-embeddings` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlAudio` | `audio` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlVision` | `vision` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlDiffusion` | `image-generation` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlSam` | `segmentation` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlMusic` | `music` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlRag` | `retrieval` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlAgents` | `agents` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlVideo` | `video` | from `ofxggml-addon.json` | planned |

## Active runtime checks

- Core runs `backend-runtime-check` on relevant pull requests and pushes to `main`.
- The reusable workflow initializes the CPU backend and runs a lightweight ggml graph compute/readback smoke on Windows and Ubuntu.
- The macOS lane currently verifies the runtime-smoke scaffold without compiling the local ggml runtime.
- Local Windows validation can require CUDA with `scripts\build-runtime-smoke.ps1 -Backend cpu,cuda -RequireBackend`.

## Initial runtime checks

- keep backend discovery commands/scripts available
- keep CPU backend initialization and graph smoke active in CI
- verify optional GPU backends are reported as available/unavailable without failing the whole workflow
- separate hard failures from optional backend absence

## Future runtime checks

- model-backed CPU inference smoke test with tiny fixture
- CUDA runtime discovery in a GPU-capable runner
- Metal runtime initialization and graph smoke on macOS
- Vulkan runtime discovery where available
- backend capability report uploaded as release evidence from CI