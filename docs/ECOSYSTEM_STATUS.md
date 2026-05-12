# Ecosystem Status

This tracks the current addon-family baseline after the first companion split.

## Release Heads

| Addon | Current release | Current head | Scope |
| --- | --- | --- | --- |
| `ofxGgmlCore` | `v1.0.1` at `2171e8b` | `7451505` | backend-neutral ggml setup, runtime discovery, shared helper APIs |
| `ofxGgmlLlama` | `v1.0.1` | `b9b7374` | llama.cpp server/CLI tools, text, chat, embeddings |
| `ofxGgmlSam` | `v1.0.1` | `ad07e89` | SAM request/result bridge, multi-point external adapter contract, point example mask UI |
| `ofxGgmlAudio` | `v1.0.1` | `9aa8207` | audio stream helpers, Whisper lane, rolling chunk transcript GUI, transcription example |
| `ofxGgmlMusic` | `v1.0.1` | `21f9d3d` | music request types, procedural generation, external MusicGen profile, manifests, MIDI/stem outputs |
| `ofxGgmlDiffusion` | `v1.0.1` | `f1803f5` | diffusion request types, shared image backend interface, GAN proof lane, native bridge smoke |
| `ofxGgmlVision` | `v1.0.1` | `74ff86a` | image understanding request/example baseline |
| `ofxGgmlVideo` | `v1.0.1` | `431f436` | video/frame request/example baseline |
| `ofxGgmlRag` | `v1.0.1` | `c0ac283` | citation search request/example baseline |
| `ofxGgmlAgents` | `v1.0.1` | `b81a5e0` | planning request/example baseline |

Core `main` is ahead of the `v1.0.1` tag only for family-map documentation.
Do not retag Core for documentation-only changes unless preparing a new patch
release.

## Baseline Standard

Every active companion now has:

- public version metadata in its umbrella header
- release notes, changelog, release policy, and release checklist
- `scripts\release-candidate.*`
- `scripts\validate-local.*`
- root-level openFrameworks example placement
- headless request/helper tests
- generated artifact hygiene rules

## Next Backend Priorities

Pick one backend lane and make it genuinely useful before widening the whole
family again.

1. `ofxGgmlDiffusion`: test the shared native bridge with a tiny local model
   fixture, then wire PhotoMaker only if the installed C API supports it.
2. `ofxGgmlSam`: choose the first real SAM/SAM2/SAM3 runner and document
   setup/download notes against the tested multi-point adapter contract.
3. `ofxGgmlAudio`: add a dedicated live microphone streaming example.
4. `ofxGgmlMusic`: add a smoke mode for machines with a configured
   Hugging Face MusicGen Python environment.

RAG, Agents, Vision, and Video should stay narrow until one lower-level runtime
path is proven and reusable.

## Local State Notes

Generated ggml files under Core and generated Whisper files under Audio are
local runtime state. They should remain ignored.

`ofxGgmlCore/addon_config.mk` may differ locally after `setup-ggml`; that is an
environment selection file, not a family-map change.
