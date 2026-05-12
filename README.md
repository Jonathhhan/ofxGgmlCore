# ofxGgmlCore

`ofxGgmlCore` is the backend-neutral openFrameworks base addon for the
ofxGgml family. It owns ggml setup, runtime discovery, small shared C++ helpers,
and a smoke-test example. Model-specific workflows live in companion addons.

## Addon Family

The active repos now share a common baseline: a README, docs, root-level
openFrameworks examples, `scripts\validate-local.*`, headless tests, and no
generated model/build artifacts committed to git.

| Addon | Lane | Current state |
| --- | --- | --- |
| [`ofxGgmlLlama`](../ofxGgmlLlama) | llama.cpp server/CLI tools, text, chat, and embeddings | usable companion; owns llama adapters and examples |
| [`ofxGgmlSam`](../ofxGgmlSam) | SAM/SAM2/SAM3 segmentation | seeded companion with point-prompt example baseline |
| [`ofxGgmlDiffusion`](../ofxGgmlDiffusion) | diffusion, GAN, and image generation | active native-runtime lane; first text-to-image and GAN boundaries |
| [`ofxGgmlAudio`](../ofxGgmlAudio) | Whisper, transcription, denoising, voice, and stream inference | seeded audio lane; Whisper belongs here first |
| [`ofxGgmlMusic`](../ofxGgmlMusic) | music analysis, beat/key/chord workflows, stems, and generation | hardened baseline; next real model bridge should start here or Diffusion |
| [`ofxGgmlVision`](../ofxGgmlVision) | CLIP, image embeddings, captions, and image understanding | seeded companion with image example baseline |
| [`ofxGgmlRag`](../ofxGgmlRag) | retrieval, citations, web crawl, and local search | seeded companion for document/search workflows |
| [`ofxGgmlAgents`](../ofxGgmlAgents) | tool-using local agents and planning loops | seeded companion for orchestration workflows |
| [`ofxGgmlVideo`](../ofxGgmlVideo) | video understanding, frame pipelines, temporal analysis, and generation | seeded companion for temporal workflows |

## Quick Start

From this folder:

```powershell
.\scripts\first-run.bat
.\scripts\run-simple-example.bat -Build
```

On macOS/Linux:

```sh
./scripts/first-run.sh
./scripts/run-simple-example.sh -Build
```

`first-run` sets up ggml and runs the Core doctor. The simple example verifies
that openFrameworks can include the addon, see the ggml runtime, and render a
small ofxImGui UI.

For text, chat, and embedding examples, use `ofxGgmlLlama` beside this addon:

```powershell
cd ..\ofxGgmlLlama
.\scripts\build-llama-server.bat
.\scripts\run-text-example.bat -Build -Model C:\path\to\model.gguf
.\scripts\run-chat-example.bat -Build -Model C:\path\to\model.gguf
.\scripts\run-embedding-example.bat -Build -Model C:\path\to\embedding-model.gguf
```

On macOS/Linux:

```sh
cd ../ofxGgmlLlama
./scripts/build-llama-server.sh
./scripts/run-text-example.sh -Build -Model /path/to/model.gguf
./scripts/run-chat-example.sh -Build -Model /path/to/model.gguf
./scripts/run-embedding-example.sh -Build -Model /path/to/embedding-model.gguf
```

## Scripts

| Script | Purpose |
| --- | --- |
| `scripts\setup-ggml.bat` | Fetch and build ggml 0.11.0 for the selected backend |
| `scripts\first-run.bat` | Setup ggml, then run `doctor` |
| `scripts\doctor.bat` | Check local Core readiness |
| `scripts\build-simple-example.bat` | Build the Core smoke example |
| `scripts\run-simple-example.bat` | Launch the Core smoke example |
| `scripts\validate-local.bat` | Run the local Core validation suite |
| `scripts\list-models.bat` | List nearby GGUF files for companion workflows |

Backend flags for `setup-ggml` and `first-run` include `-Auto` by default,
`-CpuOnly`, `-Cuda`, `-Vulkan`, `-Metal`, `-OpenCL`, and `-AllBackends`.

## Core Contract

Core should stay small and boring:

- no model downloads
- no llama.cpp server lifecycle
- no text/chat/embedding examples
- no SAM, diffusion, audio, music, video, RAG, or agent-specific UX
- no generated build output committed to git

Core keeps shared request/result types and domain-neutral primitives. Concrete
model adapters and user-facing model workflows belong in companion addons.

## Validation

```powershell
.\scripts\validate-local.bat
```

On macOS/Linux:

```sh
./scripts/validate-local.sh
```

This checks addon headers, setup dry-runs, generated project repair, launch
dry-runs, first-run dry-runs, model listing, doctor output, and artifact hygiene.
