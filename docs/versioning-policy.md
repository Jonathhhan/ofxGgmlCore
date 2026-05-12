# ofxGgml Versioning Policy

## Goals

The ofxGgml ecosystem should evolve as a coordinated addon platform while allowing companion addons to iterate independently where practical.

## Baseline versions

The ecosystem baseline version is tracked in `ecosystem.json`.

Baseline releases represent:

- compatible repository structure
- aligned validation scripts
- aligned governance files
- aligned addon-family conventions
- compatible Core/shared primitive expectations

## Core compatibility

Companion addons should document:

- minimum supported `ofxGgmlCore` version
- backend assumptions
- platform limitations
- model/runtime assumptions

## Semantic versioning

Recommended interpretation:

- MAJOR: breaking API or architecture changes
- MINOR: additive features or workflows
- PATCH: fixes, docs, validation, CI, hygiene, or non-breaking updates

## Cross-repo synchronization

When changing shared architecture expectations:

1. update `ecosystem.json`
2. update governance/docs/templates if required
3. propagate required changes to companion addons
4. validate addon boundaries
5. update changelogs

## Release expectations

Before tagging a coordinated release:

- hygiene workflows should pass
- release-check workflows should pass
- docs should be updated
- generated artifacts should not be committed
- ecosystem dashboards should regenerate cleanly
