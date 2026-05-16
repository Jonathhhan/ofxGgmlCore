# Addon Metadata Schema

## Goal

Define a lightweight metadata format that companion addons can expose for future ecosystem compatibility validation.

## Proposed file

```txt
ofxggml-addon.json
```

## Example

```json
{
  "name": "ofxGgmlLlama",
  "lane": "text-chat-embeddings",
  "coreBaseline": "v1.0.1",
  "requires": [
    "ofxGgmlCore"
  ],
  "platforms": [
    "windows",
    "macos",
    "linux"
  ],
  "backends": [
    "cpu",
    "cuda",
    "metal",
    "vulkan"
  ],
  "inferenceSmokeReport": ".llama-runtime-smoke.json"
}
```

## New field: inferenceSmokeReport

`inferenceSmokeReport` (optional, recommended for inference/runtime-capable lanes) is the filename of the lane-owned inference smoke report expected by Core's backend-runtime planning scripts. It is read by `scripts/plan-backend-runtime-verification.ps1`.

### Migration note

Lanes that currently participate in model-backed runtime planning should add `inferenceSmokeReport` to `ofxggml-addon.json`. Core now resolves inference smoke evidence from metadata first-classly and no longer maintains a hard-coded per-lane filename map.

## Future validation possibilities

Potential future tooling:

- compatibility reconciliation
- dependency graph validation
- release train verification
- addon capability discovery
- generated compatibility dashboards
- ecosystem-wide backend support maps

## Design constraints

- Keep metadata human-readable.
- Avoid duplicating large amounts of README content.
- Preserve addon ownership boundaries.
- Prefer additive metadata evolution.
