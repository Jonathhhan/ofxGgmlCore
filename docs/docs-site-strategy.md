# Generated Docs Site Strategy

## Goal

Expose the ofxGgml ecosystem control-plane documentation as a lightweight generated documentation site.

## Initial scope

The first docs site should publish existing Markdown files from `docs/`:

- ecosystem portal index
- ecosystem dashboard
- dependency graph
- compatibility matrix
- release plan
- PR fanout plan
- workflow fanout plan
- ecosystem health report
- versioning policy
- release train strategy
- autonomous maintenance roadmap

## Recommended publishing path

Use GitHub Pages from the `docs/` folder or a generated `site/` folder.

Recommended first phase:

```txt
docs/
  portal-index.md
  ecosystem-dashboard.md
  ecosystem-dependency-graph.md
  compatibility-matrix.md
  release-plan.md
```

Recommended later phase:

```txt
site/
  index.html
  dashboard.html
  compatibility.html
  release.html
```

## Source of truth

`ecosystem.json` remains the source of truth for topology and ownership.
Generated docs should be regenerated from scripts before publishing.

## Future direction

- generated HTML site
- GitHub Pages deployment
- addon status badges
- workflow health summary
- compatibility status table
- cross-repo release train status
- generated API links per addon
