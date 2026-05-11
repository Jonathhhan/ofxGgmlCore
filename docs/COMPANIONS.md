# Companion Addons

`ofxGgml` should stay the boring core: ggml setup, runtime ownership, tensors,
graphs, model metadata, result types, and small text/chat/embedding/segmentation
boundaries. Domain workflows belong in companion addons that depend on
`ofxGgml`.

## Split Rule

Start a companion addon when a feature needs any of these:

- model-specific preprocessing or postprocessing
- committed sample media or domain assets
- a large GUI workflow
- network retrieval, indexing, memory, or agent orchestration
- dependencies that most `ofxGgml` users do not need
- examples that are more like applications than focused smoke tests

Keep a feature in core only when it is small, backend-neutral, testable without
large external assets, and useful to most downstream companion addons.

## Named Lanes

| Addon | Scope |
| --- | --- |
| `ofxGgmlSam` | SAM/SAM2/SAM3 segmentation models, masks, image prompts, segmentation UI |
| `ofxGgmlMusic` | music/audio analysis, music embeddings, generation workflows |
| `ofxGgmlSpeech` | speech recognition, transcription, voice workflows |

## Candidate Lanes

| Addon | Scope |
| --- | --- |
| `ofxGgmlVision` | CLIP, image embeddings, captions, VLM-style image understanding |
| `ofxGgmlDiffusion` | image/video diffusion and generative visual models |
| `ofxGgmlRag` | document indexing, retrieval, citations, project memory |
| `ofxGgmlAgents` | assistants, tool use, coding/workflow agents |
| `ofxGgmlVideo` | video understanding, montage, temporal analysis |
| `ofxGgmlUI` | larger optional ImGui tools, model browser, prompt workbench |

## Dependency Direction

Companion addons may depend on `ofxGgml`. `ofxGgml` must not depend on companion
addons.

Shared code can move down into `ofxGgml` only when it becomes a stable,
domain-neutral primitive with focused tests and no heavy runtime dependency.
