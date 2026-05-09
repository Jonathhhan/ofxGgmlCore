# Architecture

`main` is now the core rewrite line. The design rule is simple: if a feature is
not needed by most openFrameworks projects that want ggml access, it does not
belong in the default addon.

## Core Responsibilities

- Own and release ggml backends safely.
- Provide small tensor and graph wrappers with explicit lifetimes.
- Surface errors through `ofxGgmlResult<T>` rather than process-level aborts.
- Keep binary dependency setup reproducible.
- Provide focused examples that each prove one concept.

## Non-Core Responsibilities

These should live in companion addons or optional layers:

- assistants and coding agents
- RAG, web crawling, citation search
- SAM/SAM3, vision, speech, TTS, diffusion
- video essay, music, montage, MilkDrop, Holoscan workflows
- large all-in-one GUI experiments

## Public Header Plan

- `ofxGgmlCore.h`: low-level stable foundation
- `ofxGgmlText.h`: small text request/result API with pluggable backends
- `ofxGgml.h`: default umbrella for core, text, and stable optional bridge APIs

## Compatibility

The frozen full implementation is on `legacy-full`. New `main` can make
breaking changes freely until the first rewritten release tag.
