# ofxGgmlCore

`ofxGgmlCore` is the backend-neutral openFrameworks base addon for the
ofxGgml family. It owns ggml setup, runtime discovery, small shared C++ helpers,
and a smoke-test example. Model-specific workflows live in companion addons.

## Addon Family

| Addon | Purpose |
| --- | --- |
| [`ofxGgmlLlama`](../ofxGgmlLlama) | llama.cpp server/CLI tools, text, chat, and embedding examples |
| [`ofxGgmlSam`](../ofxGgmlSam) | SAM segmentation workflows |
| [`ofxGgmlDiffusion`](../ofxGgmlDiffusion) | diffusion and image generation workflows |
| [`ofxGgmlAudio`](../ofxGgmlAudio) | Whisper, transcription, denoising, voice conversion, emotion, and real-time stream inference |
| [`ofxGgmlMusic`](../ofxGgmlMusic) | music and audio-generation workflows |
| [`ofxGgmlVision`](../ofxGgmlVision) | vision-language and image understanding workflows |
| [`ofxGgmlRag`](../ofxGgmlRag) | retrieval, citations, and local search workflows |
| [`ofxGgmlAgents`](../ofxGgmlAgents) | tool-using local agent workflows |
| [`ofxGgmlVideo`](../ofxGgmlVideo) | video understanding and generation workflows |

## Quick Start

From this folder:

```powershell
.\scripts\first-run.bat
.\scripts\run-simple-example.bat -Build
```

`first-run` sets up ggml and runs the Core doctor. The simple example verifies
that openFrameworks can include the addon, see the ggml runtime, and render a
small ofxImGui UI.

For the old text, chat, and embedding examples, use `ofxGgmlLlama` beside this
addon:

```powershell
cd ..\ofxGgmlLlama
.\scripts\build-llama-server.bat
.\scripts\run-text-example.bat -Build -Model C:\path\to\model.gguf
.\scripts\run-chat-example.bat -Build -Model C:\path\to\model.gguf
.\scripts\run-embedding-example.bat -Build -Model C:\path\to\embedding-model.gguf
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

Core may keep shared request/result types and compatibility adapters while the
family split settles, but user-facing model workflows should move to companion
addons.

## Validation

```powershell
.\scripts\validate-local.bat
```

This checks addon headers, setup dry-runs, generated project repair, launch
dry-runs, first-run dry-runs, model listing, doctor output, and artifact hygiene.
