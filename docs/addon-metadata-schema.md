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

## `requires` and `coreBaseline`

`requires` lists direct build/runtime addon dependencies. It may be empty for a
dependency-light companion that does not compile or link Core. Smoke-project
planning requires examples to include the owner addon and exactly the declared
direct dependencies; it does not inject `ofxGgmlCore` implicitly.

`coreBaseline` remains the ecosystem compatibility baseline even when Core is
not a direct dependency.

Generated-project postflight checks both sides of this contract: every addon in
`addons.make` must be wired, and no other managed ofxGgml addon may remain as a
stale generated-project reference. Missing wiring may be repaired additively;
stale wiring requires regeneration from `addons.make`.

When regenerating ignored project files while intentional source edits are
already present, smoke-build preflight may use `-AllowDirtyRepository`. The
override is explicit and per invocation; the default still blocks dirty owners.

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
