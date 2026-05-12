# PR Fanout Execution Guide

## Purpose

Coordinate ecosystem-wide changes across the ofxGgml addon family.

## Safe fanout strategy

1. Make the source change in `ofxGgmlCore` or `ofxGgmlWorkflows`.
2. Validate the source repository.
3. Generate or review the PR fanout plan.
4. Apply one small branch per target repository.
5. Open one PR per repository.
6. Keep titles, branch names, and summaries consistent.
7. Merge in dependency order:
   - workflows first
   - Core second
   - companion addons third
8. Regenerate ecosystem docs after merge.

## Recommended branch naming

```txt
ecosystem/<short-change-name>
```

## Recommended PR title pattern

```txt
Update ecosystem standards
```

## Recommended PR body sections

```md
## Summary

## Scope

## Validation

## Ecosystem impact
```

## Safety rules

- Prefer small PRs.
- Do not mix behavior changes with governance propagation.
- Do not commit generated artifacts, models, binaries, or local caches.
- Keep Core and companion-addon boundaries explicit.
- Validate reusable workflows before broad rollout.
