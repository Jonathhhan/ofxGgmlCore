# Workflow Fanout Plan

## Current State

Core workflows have been consolidated to 5 focused pipelines. Companion addons
can consume reusable workflows from `Jonathhhan/ofxGgmlWorkflows` for specific
checks:

```yaml
jobs:
  hygiene:
    uses: Jonathhhan/ofxGgmlWorkflows/.github/workflows/addon-hygiene.yml@main
```

## Benefits

- centralized CI maintenance
- ecosystem-wide policy upgrades
- thinner addon repos
- consistent automation behavior
- simpler ecosystem governance