# Ecosystem Status

This tracks the current addon-family baseline after the first companion split.

## Release Heads

| Addon | Current release | Current head | Scope |
| --- | --- | --- | --- |
| `ofxGgmlCore` | `v1.0.1` at `2171e8b` | `21923ae` | backend-neutral ggml setup, runtime discovery, shared helper APIs |
| `ofxGgmlLlama` | `v1.0.1` | `b9b7374` | llama.cpp server/CLI tools, text, chat, embeddings |
| `ofxGgmlSam` | `v1.0.1` | `ea0d054` | SAM request/result bridge, external adapter boundary, point example mask UI |
| `ofxGgmlAudio` | `v1.0.1` | `a0971c7` | audio stream helpers, Whisper lane, transcription example, headless transcription smoke |
| `ofxGgmlMusic` | `v1.0.1` | `00f0ac8` | music request types, procedural generation, manifests, MIDI/stem outputs, external model bridge |
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

1. `ofxGgmlSam`: document one concrete local SAM/SAM2/SAM3 executable contract
   with setup or download notes.
2. `ofxGgmlMusic`: connect the external bridge to one concrete local music
   generator executable and document its model/setup path.
3. `ofxGgmlAudio`: extend the verified Whisper path into streaming chunks,
   timestamps, and subtitle export.
4. `ofxGgmlDiffusion`: connect the stable-diffusion.cpp bridge to the shared
   image backend interface and then test with a tiny local model fixture.

RAG, Agents, Vision, and Video should stay narrow until one lower-level runtime
path is proven and reusable.

## Local State Notes

Generated ggml files under Core and generated Whisper files under Audio are
local runtime state. They should remain ignored.

`ofxGgmlCore/addon_config.mk` may differ locally after `setup-ggml`; that is an
environment selection file, not a family-map change.
