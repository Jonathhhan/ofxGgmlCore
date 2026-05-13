# ofxGgmlCore

`ofxGgmlCore` is the backend-neutral openFrameworks base addon for the
ofxGgml family. It owns ggml setup, runtime discovery, small shared C++ helpers,
and a smoke-test example. Model-specific workflows live in companion addons.

## Addon Family

The active repos now share a tagged `v1.0.1` baseline: a README, docs,
root-level openFrameworks examples, `scripts\validate-local.*`,
`scripts\release-candidate.*`, headless tests, release notes, and no generated
model/build artifacts committed to git.

| Addon | Lane | Current state |
| --- | --- | --- |
| [`ofxGgmlLlama`](../ofxGgmlLlama) | llama.cpp server/CLI tools, text, chat, and embeddings | `v1.0.1`; usable companion with llama adapters and examples |
| [`ofxGgmlSam`](../ofxGgmlSam) | SAM/SAM2/SAM3 segmentation | `v1.0.1`; bridge and point-prompt example baseline |
| [`ofxGgmlDiffusion`](../ofxGgmlDiffusion) | diffusion, GAN, and image generation | `v1.0.1`; native-runtime lane with text-to-image, GAN boundaries, PhotoMaker bridge, doctor, and generated-project repair |
| [`ofxGgmlAudio`](../ofxGgmlAudio) | Whisper, transcription, denoising, voice, and stream inference | `v1.0.1`; audio lane with Whisper setup and transcribe example |
| [`ofxGgmlMusic`](../ofxGgmlMusic) | music analysis, beat/key/chord workflows, stems, and generation | `v1.0.1`; procedural generation baseline with manifests and CLI |
| [`ofxGgmlVision`](../ofxGgmlVision) | CLIP, image embeddings, captions, and image understanding | `v1.0.1`; image request/example baseline |
| [`ofxGgmlRag`](../ofxGgmlRag) | retrieval, citations, web crawl, and local search | `v1.0.1`; citation search request/example baseline |
| [`ofxGgmlAgents`](../ofxGgmlAgents) | tool-using local agents and planning loops | `v1.0.1`; planning request/example baseline |
| [`ofxGgmlVideo`](../ofxGgmlVideo) | video understanding, frame pipelines, temporal analysis, and generation | `v1.0.1`; video frame request/example baseline |

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
.\scripts\run-example.bat text -Build -Model C:\path\to\model.gguf
.\scripts\run-example.bat chat -Build -Model C:\path\to\model.gguf
.\scripts\run-example.bat embedding -Build -Model C:\path\to\embedding-model.gguf
```

On macOS/Linux:

```sh
cd ../ofxGgmlLlama
./scripts/build-llama-server.sh
./scripts/run-example.sh text -Build -Model /path/to/model.gguf
./scripts/run-example.sh chat -Build -Model /path/to/model.gguf
./scripts/run-example.sh embedding -Build -Model /path/to/embedding-model.gguf
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
| `scripts\release-candidate.bat` | Run the pre-release validation gate |
| `scripts\get-ecosystem.ps1` | Shared auto-discovery helper for ofxGgml sibling repositories |
| `scripts\audit-ecosystem.bat` | Audit managed and detected repositories for agent readiness |
| `scripts\plan-ecosystem.bat` | Generate an agent-facing ecosystem planning handoff |
| `scripts\status-family.bat` | Print the local ofxGgml addon-family status |
| `scripts\write-agent-instructions.bat` | Refresh Codex/Copilot instructions across active addon repos |
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

For ecosystem planning agents, use `scripts\plan-ecosystem.bat` to summarize
repository state and guardrails before changing addon source. The agent scripts
load managed lane metadata from `docs\ECOSYSTEM_MANIFEST.json`, auto-detect
sibling `ofxGgml*` repositories, and attach known lane metadata where
available.
Use `scripts\audit-ecosystem.bat` when you need a compact readiness matrix for
agent instructions, reusable workflow coverage, validation, and release gates.

For Hermes Agent, Codex, and GitHub Copilot support, use
`scripts\write-agent-instructions.bat` to generate `HERMES.md`, `AGENTS.md`,
and `.github\copilot-instructions.md` across the active addon and workflow
repos.

## Validation

```powershell
.\scripts\validate-local.bat
```

Before tagging or publishing a release candidate:

```powershell
.\scripts\release-candidate.bat
```

On macOS/Linux:

```sh
./scripts/validate-local.sh
./scripts/release-candidate.sh
```

This checks addon headers, setup dry-runs, generated project repair, launch
dry-runs, first-run dry-runs, model listing, doctor output, and artifact hygiene.
