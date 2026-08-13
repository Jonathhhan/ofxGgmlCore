# Cross-Repo Metadata Strategy

## Goal

Use `ecosystem.json` together with each repository's `ofxggml-addon.json` to validate the ecosystem against real addon metadata.

## Current checks

- repository metadata exists
- addon name matches ecosystem registration
- lane matches ecosystem registration
- `coreBaseline` matches ecosystem baseline
- each example declares its owner addon plus the addon's explicit `requires`
- dependency-light companion addons may keep `requires` empty; `coreBaseline` still records ecosystem compatibility

## Generated reports

- `docs/metadata-reconciliation-report.md`
- `docs/cross-repo-capability-map.md`

## Future checks

- backend declarations vs CI coverage
- platform declarations vs matrix builds
- minimum Core compatibility
- stale addon metadata detection
- unregistered repository detection
- release readiness validation

## Safety rule

Metadata may be aspirational only when clearly documented. Future release checks should distinguish between declared capability and validated capability.
