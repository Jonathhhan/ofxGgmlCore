# ofxGgmlCore

`ofxGgmlCore` is the backend-neutral openFrameworks base addon for the
ofxGgml family. It owns ggml setup, runtime discovery, shared C++ primitives,
and a smoke-test example. Model-specific workflows live in companion addons.

## Addon Family

| Addon | Lane |
| --- | --- |
| [`ofxGgmlLlama`](../ofxGgmlLlama) | llama.cpp server/CLI, text, chat, embeddings |
| [`ofxGgmlSam`](../ofxGgmlSam) | SAM/SAM2/SAM3 segmentation |
| [`ofxGgmlDiffusion`](../ofxGgmlDiffusion) | diffusion, GAN, image generation |
| [`ofxGgmlAudio`](../ofxGgmlAudio) | Whisper, transcription, audio |
| [`ofxGgmlMusic`](../ofxGgmlMusic) | music analysis and generation |
| [`ofxGgmlVision`](../ofxGgmlVision) | CLIP, image embeddings, captions |
| [`ofxGgmlRag`](../ofxGgmlRag) | retrieval, citations, search |
| [`ofxGgmlAgents`](../ofxGgmlAgents) | tool-using local agents |
| [`ofxGgmlVideo`](../ofxGgmlVideo) | video understanding and generation |

## Quick Start

```powershell
.\scripts\first-run.bat
.\scripts\run-simple-example.bat -Build
```

`first-run` sets up ggml and runs the Core doctor. The Core example verifies
that openFrameworks can include the addon, see the ggml runtime, and render
a small ofxImGui UI.

For text, chat, and embedding examples, use `ofxGgmlLlama`:

```powershell
cd ..\ofxGgmlLlama
.\scripts\build-llama-server.bat
.\scripts\run-example.bat text -Build -Model C:\path\to\model.gguf
```

## Scripts

Core scripts are PowerShell (`.ps1`) with Windows batch wrappers (`.bat`).
On macOS/Linux, run via `pwsh -File scripts\<name>.ps1`.

| Script | Purpose |
| --- | --- |
| `scripts\setup-ggml.ps1` | Fetch and build ggml for the selected backend |
| `scripts\first-run.ps1` | Setup ggml, then run doctor |
| `scripts\doctor.ps1` | Check local Core readiness |
| `scripts\build-simple-example.ps1` | Build the Core smoke example |
| `scripts\run-simple-example.ps1` | Launch the Core smoke example |
| `scripts\validate-local.ps1` | Run the local validation suite |
| `scripts\release-candidate.ps1` | Pre-release validation gate |
| `scripts\list-models.ps1` | List nearby GGUF files |
| `scripts\plan-ecosystem.ps1` | Ecosystem planning handoff |
| `scripts\status-family.ps1` | Local addon-family status |
| `scripts\audit-ecosystem.ps1` | Ecosystem readiness audit |

Backend flags: `-Auto` (default), `-CpuOnly`, `-Cuda`, `-Vulkan`, `-Metal`, `-AllBackends`.

## Threading

- Core API calls are synchronous but should run on worker threads for heavy inference.
- Keep OpenGL work (`ofTexture`/`ofImage`) in the GL thread.
- Use `ofThread` for background inference. See [docs/THREADING.md](docs/THREADING.md).

## Core Contract

Core stays small and boring:

- no model downloads
- no llama.cpp server lifecycle
- no model-specific UX or examples
- no generated build output committed to git

Core keeps shared request/result types and domain-neutral primitives.
Concrete model adapters belong in companion addons.

See [docs/CORE_CONTRACT.md](docs/CORE_CONTRACT.md) for the full contract.

## Validation

```powershell
.\scripts\validate-local.bat
```

Before tagging a release:

```powershell
.\scripts\release-candidate.bat
```