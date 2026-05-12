# Ecosystem Status

This tracks the current addon-family baseline after the first companion split.

## Release Heads

| Addon | Current release | Current head | Scope |
| --- | --- | --- | --- |
| `ofxGgmlCore` | `v1.0.1` at `2171e8b` | `1ae3958` | backend-neutral ggml setup, runtime discovery, shared helper APIs |
| `ofxGgmlLlama` | `v1.0.1` | `b9b7374` | llama.cpp server/CLI tools, text, chat, embeddings |
| `ofxGgmlSam` | `v1.0.1` | `91dd6c7` | SAM request/result bridge, external adapter boundary, mock contract test, point example mask UI |
| `ofxGgmlAudio` | `v1.0.1` | `e765854` | audio stream helpers, Whisper lane, timestamped subtitle export, transcription example |
| `ofxGgmlMusic` | `v1.0.1` | `12b566e` | music request types, procedural generation, manifests, MIDI/stem outputs, external bridge contract |
| `ofxGgmlDiffusion` | `v1.0.1` | `c3c1414` | diffusion request types, native bridge boundary, GAN proof lane, native bridge smoke |
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

1. `ofxGgmlMusic`: connect the tested external bridge to one concrete
   model-backed local music generator and document its model/setup path.
2. `ofxGgmlAudio`: extend timestamped Whisper transcription into a documented
   rolling chunk workflow.
3. `ofxGgmlDiffusion`: connect the stable-diffusion.cpp bridge to the shared
   image backend interface and then test with a tiny local model fixture.
4. `ofxGgmlSam`: choose the first real SAM/SAM2/SAM3 runner and document
   setup/download notes against the tested external adapter contract.

RAG, Agents, Vision, and Video should stay narrow until one lower-level runtime
path is proven and reusable.

## Local State Notes

Generated ggml files under Core and generated Whisper files under Audio are
local runtime state. They should remain ignored.

`ofxGgmlCore/addon_config.mk` may differ locally after `setup-ggml`; that is an
environment selection file, not a family-map change.
