# Coding Agent Instructions

The ofxGgml family uses repository instruction files so Codex, GitHub Copilot,
and other coding assistants start with the same addon boundaries, workflow
automation boundaries, and validation rules.

Generate or refresh instructions from `ofxGgmlCore`:

```powershell
.\scripts\write-agent-instructions.ps1
```

On macOS/Linux:

```sh
./scripts/write-agent-instructions.sh
```

This writes three instruction files into each active addon and workflow
repository:

- `HERMES.md` for Hermes Agent project context.
- `AGENTS.md` for Codex-style agent guidance.
- `.github/copilot-instructions.md` for GitHub Copilot repository instructions.

For addon repositories, it also writes
`.github/workflows/coding-agent-instructions.yml`, a small caller workflow that
uses the reusable check from `ofxGgmlWorkflows`.

Use `-DryRun` to preview targets and `-Check` to fail when generated instruction
files or caller workflows are missing or stale.

Audit instruction and workflow readiness with:

```powershell
.\scripts\audit-ecosystem.ps1
```

The generator and status tools load managed repository metadata from
`docs/ECOSYSTEM_MANIFEST.json`, then use `scripts/get-ecosystem.ps1` to
auto-detect sibling repositories named `ofxGgml*`. Known repositories receive
curated lane metadata; newly detected repositories receive fallback metadata
until they are classified. `write-agent-instructions.*` updates known
repositories by default; use `-IncludeDiscovered` only after confirming newly
detected siblings should join the managed ecosystem.

The generated instructions are intentionally high-level. They tell agents,
including Hermes Agent, to keep each companion addon inside its lane, avoid
committing generated artifacts, preserve `ofxGgmlCore` as the shared base, and
run the local validation script before handoff.

For ecosystem improvement work, use `docs/ECOSYSTEM_AGENT.md` and
`scripts/plan-ecosystem.*` first. The planning agent layer should improve
instructions, reusable workflows, status reporting, and validation before it
touches addon source code.

`ofxGgmlWorkflows` is included as the reusable GitHub Actions workflow repo. It
owns `.github/workflows/coding-agent-instructions.yml`; companion addons consume
that workflow through `workflow_call`.
