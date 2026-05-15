# Local Codex llama-server Handoff

This guide describes an optional local coding-agent setup for Codex-compatible
tools that can talk to an OpenAI-compatible `llama-server` endpoint. It is an
operator handoff, not an addon runtime feature: `ofxGgmlCore` should keep the
ecosystem guardrails, validation commands, and planning queue, while the local
server, model files, and endpoint credentials stay outside git.

## When to Use

Use a local Codex endpoint for repository-local planning, documentation updates,
validation queue triage, and small reviewable patches. Treat the local model as
a helper, not release truth. Release decisions still need workflow evidence,
smoke-build evidence, and `scripts\release-candidate.bat`.

Do not use this setup to bypass lane ownership. Model-specific runtime work
still belongs in the companion addon that owns the lane. Generated projects,
downloaded runtimes, model weights, caches, and local server logs must remain
uncommitted.

## Server Shape

Run an OpenAI-compatible `llama-server` on localhost from your local llama.cpp
or companion-addon runtime checkout. Keep the model path outside the repository
unless an owning addon explicitly tracks a tiny test fixture.

Example:

```powershell
.\llama-server.exe `
	-m C:\models\qwen2.5-coder-7b-instruct-q4_k_m.gguf `
	--host 127.0.0.1 `
	--port 8080 `
	--ctx-size 8192
```

The expected endpoint shape is:

```text
http://127.0.0.1:8080/v1
```

Bind to `127.0.0.1` unless you have a specific reason to expose the server to
another machine. Do not publish a local endpoint or API token in repository
files.

To auto-detect whether the local endpoint and Codex config are visible from the
repository, run:

```powershell
scripts\plan-local-codex.bat -Json -SummaryOnly
```

The planner probes only localhost OpenAI-compatible `/v1/models` endpoints and
reads local Codex config candidates. It does not start a server, write config,
or change addon runtime behavior.

## Codex Provider Sketch

Codex provider configuration can change between installed versions, so verify
the exact keys against your local Codex documentation before relying on this
sketch. The important contract for the ofxGgml ecosystem is the endpoint shape
and the repository guardrail prompt, not the specific TOML field names.

Illustrative `%USERPROFILE%\.codex\config.toml` shape:

```toml
[model_providers.local_llama]
name = "local-llama"
base_url = "http://127.0.0.1:8080/v1"
env_key = "LOCAL_LLAMA_API_KEY"
wire_api = "chat"

[profiles.ofxggml_local]
model = "local-coder"
model_provider = "local_llama"
```

Most local OpenAI-compatible servers ignore the API key, but some clients still
expect the referenced environment variable to exist:

```powershell
$env:LOCAL_LLAMA_API_KEY = "local"
```

Use the wire API supported by your installed Codex version and the local
server. For llama.cpp-style OpenAI-compatible servers, the chat/completions
surface is the conservative starting point.

## Required Repository Prompt

Use this prompt fragment before asking a local model to change files in this
ecosystem:

```text
Before editing, run scripts\plan-ecosystem.bat -Json -SummaryOnly and
scripts\plan-coding-agent-work.bat -Json.

Work only in planning, documentation, workflow, validation, or instruction
files unless the user explicitly names a companion addon behavior.

Keep ofxGgmlCore backend-neutral. Do not add reverse dependencies from Core to
companion addons.

Do not commit generated projects, binaries, model weights, downloaded runtimes,
sample media dumps, memory indexes, logs, or caches.

Validate focused changes locally. Before handoff, run
scripts\release-candidate.bat.
```

## Handoff Commands

Start with compact planning evidence:

```powershell
scripts\plan-local-codex.bat -Json -SummaryOnly
scripts\plan-ecosystem.bat -Json -SummaryOnly
scripts\plan-coding-agent-work.bat -Json
scripts\check-ecosystem-readiness.bat -SkipDoctorTests -Json -SummaryOnly
```

Before selecting model-backed runtime work, ask for runtime planning evidence:

```powershell
scripts\plan-backend-runtime-verification.bat -Json -SummaryOnly
scripts\list-models.bat -Json -SummaryOnly
```

Before release or PR handoff, run:

```powershell
scripts\release-candidate.bat
```

## Operating Rules

- Keep local model setup local; do not make `ofxGgmlCore` own server lifecycle.
- Prefer one repository-scoped task over broad fanout.
- Treat local model suggestions as untrusted until validation passes.
- Use workflow and smoke-build evidence for release gates.
- Keep classified reference repositories out of generated automation unless
  they are intentionally promoted.
