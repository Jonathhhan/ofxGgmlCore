# Release Train Strategy

## Goal

Coordinate ecosystem-wide releases across the ofxGgml addon family while preserving addon ownership boundaries.

## Recommended release order

1. `ofxGgmlWorkflows`
2. `ofxGgmlCore`
3. companion addons

## Companion addon order

Suggested propagation order:

1. ofxGgmlLlama
2. ofxGgmlAudio
3. ofxGgmlVision
4. ofxGgmlDiffusion
5. ofxGgmlSam
6. ofxGgmlMusic
7. ofxGgmlRag
8. ofxGgmlAgents
9. ofxGgmlVideo

## Release-train checklist

- reusable workflows validated
- ecosystem health checks passing
- compatibility matrix regenerated
- release plan regenerated
- ecosystem dashboard regenerated
- changelogs updated
- workflow fanout reviewed
- PR fanout reviewed
- artifact hygiene verified

## Safety rules

- Prefer small synchronized releases.
- Avoid mixing large refactors with governance propagation.
- Keep Core backend-neutral.
- Preserve companion-addon ownership boundaries.
- Validate reusable workflows before ecosystem rollout.

## Future direction

Potential future automation:

- generated release trains
- automated compatibility checks
- coordinated changelog synthesis
- automated release note aggregation
- metadata-driven ecosystem synchronization
