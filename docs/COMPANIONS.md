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

## Baseline Contract

Every active companion addon should keep the same boring project shape:

- root-level README with clone/setup/run instructions
- docs for architecture, roadmap, examples, and release notes when the addon
  has public workflow decisions
- independent version metadata exposed through the public umbrella header
- one or more root-level openFrameworks examples, with `ofxImGui` allowed for
  example UX
- `scripts\validate-local.bat`, `scripts\validate-local.ps1`, and
  `scripts\validate-local.sh` where practical
- `scripts\release-candidate.*` for pre-tag checks where practical
- headless request/helper tests that do not need model downloads
- no generated build output, model files, sample media dumps, or runtime caches
  committed to git

Use this baseline before adding new features. If a companion cannot pass this
shape, fix the addon structure before widening the API.

## Named Lanes

| Addon | Scope | Current state |
| --- | --- | --- |
| `ofxGgmlLlama` | llama.cpp server/CLI tools, text/chat/embedding examples, adapters, launch scripts | v1.0.1 companion |
| `ofxGgmlSam` | SAM/SAM2/SAM3 segmentation models, masks, image prompts, segmentation UI | v1.0.1 companion |
| `ofxGgmlAudio` | real-time audio inference, Whisper, transcription, denoising, voice conversion, emotion, voice workflows | v1.0.1 companion |
| `ofxGgmlMusic` | music analysis, beat/downbeat, tempo, key/chord, stems, music embeddings, generation workflows | v1.0.1 companion |
| `ofxGgmlDiffusion` | Stable Diffusion/SDXL/Flux-style image workflows, GAN-style image generation, identity adapters such as PhotoMaker | v1.0.1 companion |
| `ofxGgmlVision` | CLIP, image embeddings, captions, VLM-style image understanding | v1.0.1 companion |
| `ofxGgmlRag` | document ingestion, web crawl, retrieval, citations, project memory | v1.0.1 companion |
| `ofxGgmlAgents` | assistants, tool use, planning loops, workflow automation | v1.0.1 companion |
| `ofxGgmlVideo` | video understanding, frame pipelines, temporal analysis, temporal GAN and video generation | v1.0.1 companion |

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

`ofxGgmlLlama` is the home for llama.cpp-specific runtime tooling: server
lifecycle scripts, CLI fallback, text/chat/embedding examples, concrete
adapters, and llama.cpp build helpers. `ofxGgmlCore` keeps only backend-neutral
text and embedding request/result APIs.

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

## Next Milestone Rule

Do not broaden every companion at once. Pick one addon and make it genuinely
useful with a repeatable local backend path, then copy the proven pattern.
Current best candidates are:

- `ofxGgmlAudio`: verify and polish the Whisper transcription path end to end
  with a tiny downloaded model and sample WAV.
- `ofxGgmlDiffusion`: finish the stable-diffusion.cpp bridge and keep GAN as an
  explicit experimental path.
- `ofxGgmlMusic`: add the first real music-generation backend boundary after
  the CLI/request validation baseline.
- `ofxGgmlSam`: wire the first concrete SAM/SAM2/SAM3 adapter after the point
  prompt example can load an image and preview a mask.

See `docs/ECOSYSTEM_STATUS.md` for the current release-head map.
