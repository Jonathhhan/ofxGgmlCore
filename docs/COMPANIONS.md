# Companion Addons

`ofxGgmlCore` should stay the boring core: ggml setup, runtime ownership, tensors,
graphs, model metadata, result types, and small, stable inference boundaries.
Domain workflows belong in companion addons that depend on `ofxGgmlCore`.

## Split Rule

Start a companion addon when a feature needs any of these:

- model-specific preprocessing or postprocessing
- committed sample media or domain assets
- a large GUI workflow
- network retrieval, indexing, memory, or agent orchestration
- dependencies that most `ofxGgmlCore` users do not need
- examples that are more like applications than focused smoke tests

Keep a feature in core only when it is small, backend-neutral, testable without
large external assets, and useful to most downstream companion addons.

## Named Lanes

| Addon | Scope |
| --- | --- |
| `ofxGgmlSam` | SAM/SAM2/SAM3 segmentation models, masks, image prompts, segmentation UI |
| `ofxGgmlLlama` | llama.cpp server/CLI tools, text/chat/embedding examples, launch scripts |
| `ofxGgmlMusic` | music analysis, beat/downbeat, tempo, key/chord, music embeddings, generation workflows |
| `ofxGgmlAudio` | real-time audio inference, Whisper, transcription, denoising, voice conversion, emotion, voice workflows |
| `ofxGgmlDiffusion` | Stable Diffusion/SDXL/Flux-style image workflows, GAN-style image generation, identity adapters such as PhotoMaker |
| `ofxGgmlVision` | CLIP, image embeddings, captions, VLM-style image understanding |
| `ofxGgmlRag` | document ingestion, web crawl, retrieval, citations, project memory |
| `ofxGgmlAgents` | assistants, tool use, planning loops, workflow automation |
| `ofxGgmlVideo` | video understanding, frame pipelines, temporal analysis, temporal GAN and video generation |

## Candidate Lanes

| Addon | Scope |
| --- | --- |
| `ofxGgmlUI` | larger optional ImGui tools, model browser, prompt workbench |

## Dependency Direction

Companion addons may depend on `ofxGgmlCore`. `ofxGgmlCore` must not depend on companion
addons.

Shared code can move down into `ofxGgmlCore` only when it becomes a stable,
domain-neutral primitive with focused tests and no heavy runtime dependency.

## Llama Split Status

`ofxGgmlLlama` has been seeded as the home for llama.cpp-specific runtime
tooling: server lifecycle scripts, CLI fallback, text/chat/embedding examples,
and llama.cpp build helpers. The current `ofxGgmlCore` text/embedding APIs are
transitional compatibility pieces until the companion builds are fully proven
and the core surface can be narrowed without breaking dependent addons.

`ofxGgmlAudio` covers real-time audio inference, not just transcription.
Whisper.cpp belongs inside that audio lane first. Do not create a separate
`ofxGgmlWhisper` addon unless the Whisper layer grows into a larger reusable
runtime with multiple consumers outside audio workflows.

`ofxGgmlMusic` stays separate from `ofxGgmlAudio`. Music may depend on Audio for
stream chunking, PCM, VAD, and lightweight features, but owns music-specific
terms, examples, models, and workflows such as beats, key/chords, stems,
embeddings, arrangement, and generation.

`ofxGgmlDiffusion` is the planned home for PhotoMaker-style identity adapters
and image GAN generation. Do not create `ofxGgmlPhotoMaker` unless identity
personalization grows into a larger cross-addon layer with several
non-diffusion consumers.

Diffusers is a useful design reference for `ofxGgmlDiffusion` terminology:
pipelines, schedulers, model families, and adapters. Treat it as inspiration
for C++ API shape, not as a runtime dependency for the addon family.
