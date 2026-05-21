# Hermes Agent Workflow

Hermes should work as the ecosystem planning and hygiene agent for the
ofxGgml addon family. It should start from Core, select one bounded task, and
only move into addon source when the user explicitly asks for addon behavior.

## Integration Stance

Hermes integration should make Core a control-plane entry point, not a runtime
dependency. Core should own handoff generation, guardrails, validation command
selection, and generated-artifact hygiene. Companion addons should own their
model-specific setup, examples, and runtime smoke commands.

Treat committed handoff files such as `docs\HERMES_HANDOFF.md` as reviewable
snapshots only. The canonical inputs are the current repository state plus
`scripts\status-family.*`, `scripts\plan-ecosystem.*`, and
`scripts\plan-coding-agent-work.*`; rerun the generator before using a handoff
for new work.

Hermes should default to an explicit human-launched session. Windows auto-start
is allowed only as an opt-in operator convenience for the Hermes gateway after
provider, platform, and hook configuration has been tested in the foreground.
Do not make Scheduled Task installation part of normal validation or release
readiness.

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
platform, hook configuration, and project-local handoff prompts. If an operator
installs the Scheduled Task, document that it is local machine state and keep it
out of release/readiness evidence.

For machine-readable handoff data:

```powershell
scripts\plan-hermes-handoff.ps1 -Json -SummaryOnly
```

To write a reviewable prompt file:

```powershell
scripts\plan-hermes-handoff.ps1 -OutputPath docs\HERMES_HANDOFF.md
```

That file is a point-in-time artifact. Do not treat an old committed handoff as
canonical; rerun the command and compare the selected task before acting.

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
snippets for a local OpenAI-compatible `llama-server` endpoint, and should be
the place to add Hermes profile/config examples for `base_url`, model alias,
and API-key handling. Hermes integration here should point at those examples
rather than copying llama.cpp server lifecycle or GGUF paths into Core. Core may
probe and report local-provider readiness, but Llama owns fixes when the server,
model id, or provider profile is missing.

## Managed Stable Diffusion Lane

`ofxGgmlStableDiffusion` is the promoted managed lane for stable-diffusion.cpp
image generation. Hermes handoffs should refer to that lane for image-generation
work and keep `ofxGgmlDiffusion` classified as a paused reference unless the
user explicitly promotes it. Promotion does not move image-generation runtime
code into Core; it means Core planning, readiness, and artifact-hygiene scripts
recognize `ofxGgmlStableDiffusion` as the active companion owner.

## Validation

Validate the handoff generator with:

```powershell
scripts\test-hermes-handoff.ps1
```

For broad Core validation, use the normal release/readiness path after the
focused test passes.
