# ofxGgml Ecosystem Dashboard

Baseline: `v1.0.1`

## Core

- Repo: `Jonathhhan/ofxGgmlCore`
- Role: backend-neutral primitives, ggml setup, runtime discovery, tensor/graph helpers, validation scripts

## Addons

| Addon | Lane | Repository | Owns |
| --- | --- | --- | --- |
| `ofxGgmlLlama` | `text-chat-embeddings` | `Jonathhhan/ofxGgmlLlama` | llama.cpp, text generation, chat, embeddings, server/CLI integration |
| `ofxGgmlAudio` | `audio` | `Jonathhhan/ofxGgmlAudio` | Whisper, transcription, denoising, voice, audio inference |
| `ofxGgmlVision` | `vision` | `Jonathhhan/ofxGgmlVision` | CLIP, image embeddings, captions, image understanding |
| `ofxGgmlSam` | `segmentation` | `Jonathhhan/ofxGgmlSam` | SAM, SAM2, SAM3, point prompts, segmentation examples |
| `ofxGgmlMusic` | `music` | `Jonathhhan/ofxGgmlMusic` | music analysis, beat/key/chord workflows, stems, music generation |
| `ofxGgmlRag` | `retrieval` | `Jonathhhan/ofxGgmlRag` | retrieval, citations, web crawl, local search |
| `ofxGgmlAgents` | `agents` | `Jonathhhan/ofxGgmlAgents` | tool use, planning loops, local agents |
| `ofxGgmlVideo` | `video` | `Jonathhhan/ofxGgmlVideo` | video understanding, frame pipelines, temporal analysis, video generation |

## Required files

- `README.md`
- `addon_config.mk`
- `CHANGELOG.md`
- `AGENTS.md`
- `.github/copilot-instructions.md`
- `.github/pull_request_template.md`
- `.github/workflows/addon-hygiene.yml`
- `.github/workflows/release-check.yml`

## Artifact policy

Forbidden extensions:
- `.gguf`
- `.dll`
- `.so`
- `.dylib`
- `.exe`
- `.bin`

Forbidden directories:
- `build`
- `obj`
- `.vs`
- `bin/data/models`
