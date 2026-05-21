# Hermes Agent Workflow

Hermes should work as the ecosystem planning and hygiene agent for the
ofxGgml addon family. It should start from Core, select one bounded task, and
only move into addon source when the user explicitly asks for addon behavior.

## Generate A Handoff

From `ofxGgmlCore`:

```powershell
scripts\plan-hermes-handoff.ps1
```

For a project-local setup command that writes the current handoff and prints
the selected task:

```powershell
scripts\start-hermes-agent.ps1
```

To launch Hermes after the handoff is written:

```powershell
scripts\start-hermes-agent.ps1 -Tui
```

To ask Hermes to run the selected handoff once:

```powershell
scripts\start-hermes-agent.ps1 -RunOnce
```

To run the Hermes gateway in the foreground from the project handoff context:

```powershell
scripts\start-hermes-agent.ps1 -Gateway -AcceptHooks
```

On Windows, install the Hermes gateway as an optional Scheduled Task when you
want it to auto-start at login:

```powershell
scripts\start-hermes-agent.ps1 -InstallScheduledTask
```

Keep this opt-in. The manual gateway path is better while testing provider,
platform, and hook configuration.

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
- keep `ofxGgmlDiffusion` and other classified reference repositories out of
  managed automation unless they are explicitly promoted

## Local Model Config Examples

Use `ofxGgmlLlama` for llama.cpp-backed local model configuration examples.
`ofxGgmlLlamaCodexLocalExample` owns Codex/OpenCode provider and profile
snippets for a local OpenAI-compatible `llama-server` endpoint. Hermes
integration here should point at those examples rather than copying llama.cpp
configuration into Core.

## Validation

Validate the handoff generator with:

```powershell
scripts\test-hermes-handoff.ps1
```

For broad Core validation, use the normal release/readiness path after the
focused test passes.
