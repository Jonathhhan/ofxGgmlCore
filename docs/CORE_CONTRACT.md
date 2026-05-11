# Core Contract

`ofxGgmlCore` is the shared base addon for the ofxGgml family. Its job is to be
small, predictable, and backend-neutral.

## Core Owns

- ggml setup and runtime discovery
- shared C++ utility types
- generated project repair helpers
- artifact hygiene checks
- the `ofxGgmlSimpleExample` smoke test
- family documentation links

## Core Does Not Own

- llama.cpp server lifecycle
- text, chat, or embedding examples
- SAM segmentation UX
- diffusion or image generation UX
- audio, music, vision, video, RAG, or agent workflows
- model downloads or model-specific launch policy

Those workflows belong in companion addons.

## Companion Boundaries

| Companion | Owns |
| --- | --- |
| `ofxGgmlLlama` | llama.cpp tools, text, chat, embeddings |
| `ofxGgmlSam` | SAM segmentation |
| `ofxGgmlDiffusion` | diffusion and image generation |
| `ofxGgmlAudio` | real-time audio, Whisper, denoising, voice conversion, emotion, and speech workflows |
| `ofxGgmlMusic` | music and audio generation |
| `ofxGgmlVision` | image understanding |
| `ofxGgmlRag` | retrieval, citations, search |
| `ofxGgmlAgents` | local tool-using agents |
| `ofxGgmlVideo` | video workflows |

## Compatibility Note

Core may temporarily keep shared text and embedding request/result classes while
the split matures. New examples, scripts, and model-specific documentation should
land in the relevant companion addon.
