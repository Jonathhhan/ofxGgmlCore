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
  ]
}
```

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
