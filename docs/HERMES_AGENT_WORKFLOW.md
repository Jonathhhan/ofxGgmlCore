# Hermes Agent Workflow

Hermes should work as the ecosystem planning and hygiene agent for the
ofxGgml addon family. It should start from Core, select one bounded task, and
only move into addon source when the user explicitly asks for addon behavior.

## Generate A Handoff

From `ofxGgmlCore`:

```powershell
scripts\plan-hermes-handoff.ps1
```

For machine-readable handoff data:

```powershell
scripts\plan-hermes-handoff.ps1 -Json -SummaryOnly
```

To write a reviewable prompt file:

```powershell
scripts\plan-hermes-handoff.ps1 -OutputPath docs\HERMES_HANDOFF.md
```

You can narrow the selected task:

```powershell
scripts\plan-hermes-handoff.ps1 -Repository ofxGgmlCore -Category hygiene
```

## What The Handoff Contains

- the current ecosystem summary
- the first matching coding-agent queue task
- a ready-to-paste Hermes prompt
- required context files
- planning commands Hermes should trust
- validation commands for the selected task
- guardrails that keep reference repositories out of managed automation

## Default Hermes Prompt Shape

The generated prompt tells Hermes to:

- read `HERMES.md` and `docs\ECOSYSTEM_AGENT.md`
- use Core status and planning scripts as source of truth
- take one repository-scoped task only
- work in planning, instruction, workflow, validation, or documentation files
  first
- avoid addon runtime/source edits unless the user explicitly asks for that
  repository and behavior
- keep `ofxGgmlDiffusion`, `ofxGgmlStableDiffusion`, and other classified
  reference repositories out of managed automation unless they are explicitly
  promoted

## Validation

Validate the handoff generator with:

```powershell
scripts\test-hermes-handoff.ps1
```

For broad Core validation, use the normal release/readiness path after the
focused test passes.
