# Reusable Workflow Roadmap

## Goal

Move ecosystem automation toward centralized reusable GitHub workflows and coordinated release orchestration.

## Proposed future structure

```txt
ofxGgmlWorkflows/
  .github/workflows/
    addon-hygiene.yml
    release-check.yml
    ecosystem-dashboard.yml
    compatibility-matrix.yml
```

Companion addons would consume shared workflows using:

```yaml
uses: Jonathhhan/ofxGgmlWorkflows/.github/workflows/addon-hygiene.yml@main
```

## Benefits

- centralized CI maintenance
- consistent policy enforcement
- simpler repo bootstrapping
- ecosystem-wide updates from one repository
- improved Codex predictability across repos

## Future automation ideas

- ecosystem-wide PR fanout
- semantic-release orchestration
- cross-repo version propagation
- compatibility verification
- generated docs portal
- addon dependency visualization
- ecosystem health dashboards
- automated changelog aggregation
