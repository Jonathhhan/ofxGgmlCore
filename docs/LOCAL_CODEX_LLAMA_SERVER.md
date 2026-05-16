# Local Codex llama-server Handoff

This guide describes an optional local coding-agent setup for Codex-compatible
tools that can talk to an OpenAI-compatible `llama-server` endpoint. It is an
operator handoff, not an addon runtime feature: `ofxGgmlCore` should keep the
ecosystem guardrails, validation commands, and planning queue. `ofxGgmlLlama`
owns the concrete llama.cpp build, GGUF model, `llama-server`, and
`ofxGgmlLlamaCodexLocalExample` walkthrough. Endpoint credentials stay outside
git.

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

Run an OpenAI-compatible `llama-server` on localhost from `ofxGgmlLlama` or an
explicit llama.cpp runtime checkout. Keep the model path outside the repository
unless an owning addon explicitly tracks a tiny test fixture.

Recommended `ofxGgmlLlama` path:

```powershell
cd ..\ofxGgmlLlama
scripts\build-llama-server.bat -Cuda
scripts\start-llama-server.bat `
	-ModelPath ..\models\unsloth\GLM-4.7-Flash-GGUF\GLM-4.7-Flash-UD-Q4_K_XL.gguf `
	-Port 8001 `
	-GpuLayers 999 `
	-ContextSize 131072
```

The projectGenerator-ready walkthrough lives at:

```text
ofxGgmlLlama\ofxGgmlLlamaCodexLocalExample
```

Direct llama.cpp example:

```powershell
.\llama-server.exe `
	-m C:\models\qwen2.5-coder-7b-instruct-q4_k_m.gguf `
	--host 127.0.0.1 `
	--port 8001 `
	--ctx-size 8192
```

The expected endpoint shape is:

```text
http://127.0.0.1:8001/v1
```

Bind to `127.0.0.1` unless you have a specific reason to expose the server to
another machine. Do not publish a local endpoint or API token in repository
files.

To auto-detect whether the local endpoint and Codex config are visible from the
repository, run:

```powershell
scripts\plan-local-codex.bat -Json -SummaryOnly
```

The planner probes only localhost OpenAI-compatible `/v1/models` endpoints,
reads local Codex config candidates, and emits structured recommended actions
for the detected readiness state. It does not start a server, write config, or
change addon runtime behavior.

## Codex Provider Sketch

Codex provider configuration can change between installed versions, so verify
the exact keys against your local Codex documentation before relying on this
sketch. The important contract for the ofxGgml ecosystem is the endpoint shape
and the repository guardrail prompt, not the specific TOML field names.

Illustrative `%USERPROFILE%\.codex\config.toml` shape:

```toml
[model_providers.local_llama]
name = "local-llama"
base_url = "http://127.0.0.1:8001/v1"
wire_api = "responses"

[profiles.ofxggml_local]
model = "unsloth/GLM-4.7-Flash"
model_provider = "local_llama"
```

Most local OpenAI-compatible servers ignore the API key. Add `env_key` only if
your endpoint enforces authentication:

```powershell
$env:LOCAL_LLAMA_API_KEY = "local"
```

Use the wire API supported by your installed Codex version and the local
server. Current Codex builds reject the legacy `chat` wire API for custom
providers and expect `responses`; set `model` to a model id returned by the
local `/v1/models` endpoint.

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

- Keep local model setup in `ofxGgmlLlama`; do not make `ofxGgmlCore` or
  `ofxGgmlAgents` own server lifecycle.
- Prefer one repository-scoped task over broad fanout.
- Treat local model suggestions as untrusted until validation passes.
- Use workflow and smoke-build evidence for release gates.
- Keep classified reference repositories out of generated automation unless
  they are intentionally promoted.
