# Reusable Workflow Roadmap

## Current Structure

Core now ships 5 focused workflows:

| Workflow | Purpose |
| --- | --- |
| `smoke-build-ci.yml` | Full compile loop across ecosystem |
| `release-gate.yml` | Pre-release readiness gate |
| `pages.yml` | GitHub Pages deployment |
| `backend-runtime-check.yml` | Backend runtime verification |
| `ecosystem-ci.yml` | Health, compatibility, metadata, reports |

Reusable workflows from `ofxGgmlWorkflows` are still available for companion
addons that need specific checks.

## Future Work

- ecosystem-wide PR fanout
- semantic-release orchestration
- cross-repo version propagation
- generated docs portal
- addon dependency visualization