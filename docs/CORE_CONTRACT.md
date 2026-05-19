# Core Contract

`ofxGgmlCore` is the shared base addon for the ofxGgml family. Its job is to be
small, predictable, and backend-neutral.

## Core Owns

- ggml setup and runtime discovery
- shared C++ utility types
- generated project repair helpers
- artifact hygiene checks
- the `ofxGgmlCoreExample` smoke test
- family documentation links

## Core Does Not Own

- llama.cpp server lifecycle
- text, chat, or embedding examples
- SAM segmentation UX
- diffusion, GAN, or image generation UX
- audio, music, vision, video, RAG, or agent workflows
- model downloads or model-specific launch policy

Those workflows belong in companion addons.

## Companion Boundaries

| Companion | Owns |
| --- | --- |
| `ofxGgmlLlama` | llama.cpp tools, text, chat, embeddings |
| `ofxGgmlSam` | SAM segmentation |
| `ofxGgmlDiffusion` | diffusion, GAN, and image generation |
| `ofxGgmlAudio` | real-time audio, Whisper, denoising, voice conversion, emotion, and speech workflows |
| `ofxGgmlMusic` | music analysis, beat/key/chord workflows, embeddings, and generation |
| `ofxGgmlVision` | image understanding |
| `ofxGgmlRag` | retrieval, citations, search |
| `ofxGgmlAgents` | local tool-using agents |
| `ofxGgmlVideo` | video and temporal generation workflows |

## Migration Status

Text/embedding inference modules have been moved to ofxGgmlLlama.
Segmentation and SAM3 adapters have been removed (ofxGgmlSam provides its own implementation).

Core now contains only backend-neutral primitives: runtime discovery, tensor/graph
helpers, model inspection, and shared types. New model-specific workflows should land
in the relevant companion addon from the start.
