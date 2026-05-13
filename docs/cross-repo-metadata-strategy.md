# Cross-Repo Metadata Strategy

## Goal

Use `ecosystem.json` together with each repository's `ofxggml-addon.json` to validate the ecosystem against real addon metadata.

## Current checks

- repository metadata exists
- addon name matches ecosystem registration
- lane matches ecosystem registration
- `coreBaseline` matches ecosystem baseline
- companion addons declare `ofxGgmlCore` in `requires`

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
