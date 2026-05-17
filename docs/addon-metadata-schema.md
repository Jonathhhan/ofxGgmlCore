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
  "inferenceSmokeReport": ".llama-runtime-smoke.json",
  "codexLocalPlan": "scripts/plan-local-codex.bat",
  "codexLocalSmoke": "scripts/test-local-codex.bat"
}
```

## New field: inferenceSmokeReport

`inferenceSmokeReport` (optional, recommended for inference/runtime-capable lanes) is the filename of the lane-owned inference smoke report expected by Core's backend-runtime planning scripts. It is read by `scripts/plan-backend-runtime-verification.ps1`.

### Migration note

Lanes that currently participate in model-backed runtime planning should add `inferenceSmokeReport` to `ofxggml-addon.json`. Core now resolves inference smoke evidence from metadata first-classly and no longer maintains a hard-coded per-lane filename map.

## New fields: codexLocalPlan and codexLocalSmoke

`codexLocalPlan` and `codexLocalSmoke` are optional script paths for lanes that
own a local OpenAI-compatible coding-agent endpoint. They let Core planning
surface the lane-owned preflight and non-interactive smoke command without
moving llama.cpp or Codex-specific behavior into Core.

`codexLocalPlan` should be read-only preflight. `codexLocalSmoke` may require a
running local server and should prove a real client request, for example a
`codex exec` marker response.

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
