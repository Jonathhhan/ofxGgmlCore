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
| `Jonathhhan/ofxGgmlSam` | `segmentation` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlMusic` | `music` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlRag` | `retrieval` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlAgents` | `agents` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlVideo` | `video` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlStableDiffusion` | `stable-diffusion` | from `ofxggml-addon.json` | planned |

## Active runtime checks

- Core runs `backend-runtime-check` on relevant pull requests and pushes to `main`.
- The reusable workflow initializes the CPU backend and runs a lightweight ggml graph compute/readback smoke on Windows and Ubuntu.
- Core exposes `scripts\plan-backend-runtime-verification.bat -Json -SummaryOnly` so agents can see compact CPU/CUDA/Metal/Vulkan declaration, model-path, build, and runtime-smoke readiness before selecting a companion lane.
- The macOS lane currently verifies the runtime-smoke scaffold without compiling the local ggml runtime.
- Local Windows validation can require CUDA with `scripts\build-runtime-smoke.ps1 -Backend cpu,cuda -RequireBackend`.

## Ecosystem implementation backlog

Feature metadata and README feature coverage are not the same as runtime implementation proof. Keep Core in the coordination/reporting lane and send model-specific work to the owning companion addon.

| Priority | Affected addon(s) | Missing implementation or proof | Owner | Core role |
| ---: | --- | --- | --- | --- |
| 1 | `ofxGgmlStableDiffusion` | Lane-owned runtime-smoke plan/evidence, built-example evidence, and version metadata consistency | `ofxGgmlStableDiffusion` | Coordinate and report via backend runtime verification |
| 2 | `ofxGgmlLlama`, `ofxGgmlSam`, `ofxGgmlAudio` | Fresh model-backed inference smoke evidence for existing runtime entrypoints | Owning companion addons | Report stale or missing evidence only |
| 3 | `ofxGgmlCore`, `ofxGgmlLlama`, `ofxGgmlAudio`, `ofxGgmlVision`, `ofxGgmlVideo`, `ofxGgmlRag`, `ofxGgmlAgents`, `ofxGgmlMusic`, `ofxGgmlStableDiffusion` | Generated-example build evidence for release readiness | Owning addon per example | Coordinate smoke-build target lifecycle |
| 4 | `ofxGgmlSam` | A productized SAM/SAM2/SAM3 adapter path with setup and validation | `ofxGgmlSam` | Report readiness only |
| 5 | `ofxGgmlAudio` | Dedicated live microphone/audio-stream example | `ofxGgmlAudio` | Coordinate and report only |
| 6 | `ofxGgmlMusic` | Release-grade model-backed MusicGen/AceStep smoke evidence | `ofxGgmlMusic` | Report evidence only |
| 7 | `ofxGgmlVision`, `ofxGgmlRag`, `ofxGgmlAgents`, `ofxGgmlVideo` | Real model-backed implementations after lower lanes are proven | Owning companion addons | Keep boundaries narrow and report gaps |

Use `scripts\plan-backend-runtime-verification.bat -Json -SummaryOnly`, `scripts\plan-of-smoke-build.bat`, and `scripts\plan-release-readiness.bat -Json -SummaryOnly` before selecting a companion-addon implementation task.

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
- backend runtime verification plan included as release-readiness evidence