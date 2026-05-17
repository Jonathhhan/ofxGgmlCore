# ofxGgmlCore

`ofxGgmlCore` is the backend-neutral openFrameworks base addon for the
ofxGgml family. It owns ggml setup, runtime discovery, small shared C++ helpers,
and a smoke-test example. Model-specific workflows live in companion addons.

## Addon Family

The active repos now share a tagged `v1.0.1` baseline: a README, docs,
root-level openFrameworks examples, `scripts\validate-local.*`,
`scripts\release-candidate.*`, headless tests, release notes, and no generated
model/build artifacts committed to git.

| Addon | Lane | Current state |
| --- | --- | --- |
| [`ofxGgmlLlama`](../ofxGgmlLlama) | llama.cpp server/CLI tools, text, chat, and embeddings | `v1.0.1`; usable companion with llama adapters and examples |
| [`ofxGgmlSam`](../ofxGgmlSam) | SAM/SAM2/SAM3 segmentation | `v1.0.1`; bridge and point-prompt example baseline |
| [`ofxGgmlDiffusion`](../ofxGgmlDiffusion) | diffusion, GAN, and image generation | `v1.0.1`; native-runtime lane with text-to-image, GAN boundaries, PhotoMaker bridge, doctor, and generated-project repair |
| [`ofxGgmlAudio`](../ofxGgmlAudio) | Whisper, transcription, denoising, voice, and stream inference | `v1.0.1`; audio lane with Whisper setup and transcribe example |
| [`ofxGgmlMusic`](../ofxGgmlMusic) | music analysis, beat/key/chord workflows, stems, and generation | `v1.0.1`; procedural generation baseline with manifests and CLI |
| [`ofxGgmlVision`](../ofxGgmlVision) | CLIP, image embeddings, captions, and image understanding | `v1.0.1`; image request/example baseline |
| [`ofxGgmlRag`](../ofxGgmlRag) | retrieval, citations, web crawl, and local search | `v1.0.1`; citation search request/example baseline |
| [`ofxGgmlAgents`](../ofxGgmlAgents) | tool-using local agents and planning loops | `v1.0.1`; planning request/example baseline |
| [`ofxGgmlVideo`](../ofxGgmlVideo) | video understanding, frame pipelines, temporal analysis, and generation | `v1.0.1`; video frame request/example baseline |

## Quick Start

From this folder:

```powershell
.\scripts\first-run.bat
.\scripts\run-simple-example.bat -Build
```

On macOS/Linux:

```sh
./scripts/first-run.sh
./scripts/run-simple-example.sh -Build
```

`first-run` sets up ggml and runs the Core doctor. The Core example verifies
that openFrameworks can include the addon, see the ggml runtime, and render a
small ofxImGui UI.

For text, chat, and embedding examples, use `ofxGgmlLlama` beside this addon:

```powershell
cd ..\ofxGgmlLlama
.\scripts\build-llama-server.bat
.\scripts\run-example.bat text -Build -Model C:\path\to\model.gguf
.\scripts\run-example.bat chat -Build -Model C:\path\to\model.gguf
.\scripts\run-example.bat embedding -Build -Model C:\path\to\embedding-model.gguf
```

On macOS/Linux:

```sh
cd ../ofxGgmlLlama
./scripts/build-llama-server.sh
./scripts/run-example.sh text -Build -Model /path/to/model.gguf
./scripts/run-example.sh chat -Build -Model /path/to/model.gguf
./scripts/run-example.sh embedding -Build -Model /path/to/embedding-model.gguf
```

For music-generation runtime setup, prepare AceStep once in the sibling music repo:

```powershell
cd ..\ofxGgmlMusic
.\scripts\setup-acestep-server.bat -Auto -InstallDir .\libs\acestep
```

or macOS/Linux:

```sh
cd ../ofxGgmlMusic
./scripts/setup-acestep-server.sh -Auto -InstallDir ./libs/acestep
```

## Scripts

| Script | Purpose |
| --- | --- |
| `scripts\setup-ggml.bat` | Fetch and build ggml 0.11.0 for the selected backend |
| `scripts\first-run.bat` | Setup ggml, then run `doctor` |
| `scripts\doctor.bat` | Check local Core readiness |
| `scripts\build-simple-example.bat` | Build the Core smoke example |
| `scripts\run-simple-example.bat` | Launch the Core smoke example |
| `scripts\validate-local.bat` | Run the local Core validation suite |
| `scripts\release-candidate.bat` | Run the pre-release validation gate |
| `scripts\setup-acestep-server.bat` | Prepare the AceStep ggml-backed `ace-server` helper in `ofxGgmlMusic` |
| `scripts\test-acestep-setup-dry-run.ps1` | Verify AceStep setup CLI contract without mutating files |
| `scripts\get-ecosystem.ps1` | Shared auto-discovery helper for ofxGgml sibling repositories |
| `scripts\check-ecosystem-readiness.bat` | Run the non-mutating agent readiness pass across the managed ecosystem |
| `scripts\audit-ecosystem.bat` | Audit managed and detected repositories for agent readiness |
| `scripts\plan-ecosystem.bat` | Generate an agent-facing ecosystem planning handoff |
| `scripts\plan-coding-agent-work.bat` | Generate a prioritized Codex/Copilot/Hermes-safe work queue |
| `scripts\plan-of-smoke-build.bat` | Plan openFrameworks project-generation and smoke-build rollout |
| `scripts\select-smoke-build-target.bat` | Select the next smoke-build target from the generated rollout queue |
| `scripts\plan-smoke-build-target-handoff.bat` | Generate an agent checklist for the selected smoke-build target |
| `scripts\check-smoke-build-target-preflight.bat` | Check whether the selected smoke-build target is safe to act on |
| `scripts\check-smoke-build-target-postflight.bat` | Report generated project and git impact after acting on a smoke-build target |
| `scripts\plan-smoke-build-project-repair.bat` | Plan generated Visual Studio project addon-wiring repairs |
| `scripts\plan-smoke-build-compile.bat` | Plan focused compile commands for generated examples |
| `scripts\build-smoke-example.bat` | Build a generated example that passed smoke-build postflight |
| `scripts\run-smoke-build-ci.bat` | Run the full smoke-build generate-repair-compile control-plane loop |
| `scripts\plan-doctor-rollout.bat` | Dry-run rollout plan for consistent local doctor diagnostics |
| `scripts\plan-agent-branch-cleanup.bat` | Dry-run cleanup plan for merged Codex/Copilot/Hermes branches |
| `scripts\plan-backend-runtime-verification.bat` | Dry-run runtime evidence plan for backend, model, build, and smoke-test readiness |
| `scripts\plan-local-codex.bat` | Detect optional local Codex `llama-server` endpoint and config readiness |
| `scripts\generate-workflow-status-plan.bat` | Generate the deterministic workflow-status expectation plan |
| `scripts\fetch-workflow-status.bat` | Fetch latest GitHub Actions workflow status evidence for release planning |
| `scripts\fetch-smoke-build-ci-report.bat` | Download the latest uploaded smoke-build CI JSON report artifact for release-readiness evidence |
| `scripts\plan-release-readiness.bat` | Generate non-mutating release-readiness evidence from workflow status, backend capability/runtime planning, smoke-build CI, and policy metadata |
| `scripts\assert-release-readiness.bat` | Fail the release gate when required release-readiness evidence is missing or blocked |
| `scripts\status-family.bat` | Print the local ofxGgml addon-family status |
| `scripts\write-agent-instructions.bat` | Refresh Codex/Copilot instructions across active addon repos |
| `scripts\list-models.bat` | List nearby GGUF files for companion workflows |

## Threading Notes

- `ofxGgmlCore` API calls are synchronous by design, but are intended to be used
  from worker-thread workflows when heavy inference would block the main loop.
- Keep OpenGL object work (for example `ofTexture`/`ofImage` updates and drawing)
  in the GL thread.
- Use locking around shared buffers when background threads and OF event callbacks
  both touch state.
- For background inference in openFrameworks apps, prefer `ofThread` patterns
  for lifecycle + signaling. See [docs/THREADING.md](docs/THREADING.md) and
  the ofBook thread chapter:
  <https://openframeworks.cc/ofBook/chapters/threads.html>.

Backend flags for `setup-ggml` and `first-run` include `-Auto` by default,
`-CpuOnly`, `-Cuda`, `-Vulkan`, `-Metal`, `-OpenCL`, and `-AllBackends`.

## Core Contract

Core should stay small and boring:

- no model downloads
- no llama.cpp server lifecycle
- no text/chat/embedding examples
- no SAM, diffusion, audio, music, video, RAG, or agent-specific UX
- no generated build output committed to git

Core keeps shared request/result types and domain-neutral primitives. Concrete
model adapters and user-facing model workflows belong in companion addons.

For ecosystem planning agents, use `scripts\plan-ecosystem.bat` to summarize
repository state and guardrails before changing addon source. The agent scripts
load managed lane metadata from `docs\ECOSYSTEM_MANIFEST.json`, auto-detect
sibling `ofxGgml*` repositories, and attach known lane metadata where
available.
Use `scripts\status-family.bat -Json` when an agent needs local inventory
`Summary` counts, next commands, and per-repository status before planning. The
next commands include compact ecosystem, readiness, and branch-cleanup summary
evidence, not branch deletion.
Use `scripts\status-family.bat -Json -SummaryOnly` when another agent needs
local inventory counts and compact repository summaries without the full addon
records.
Use `scripts\plan-ecosystem.bat -Json` when an agent needs structured summary,
priority, guardrail, smoke-build lifecycle, and validation-command fields.
Use `scripts\plan-ecosystem.bat -Json -SummaryOnly` when another agent needs
compact ecosystem summary evidence without the full addon inventory.
Use `scripts\plan-coding-agent-work.bat` when an agent needs the next concrete
Codex, Copilot, or Hermes-safe task. It turns local family status into a
prioritized queue with suggested files and validation commands.
Use `scripts\plan-coding-agent-work.bat -Json` when another agent needs
structured queue summary, guardrail, suggested-file, and validation-command
arrays.
Use `docs\LOCAL_CODEX_LLAMA_SERVER.md` when running optional local Codex work
against an OpenAI-compatible `llama-server` endpoint. Local model serving stays
outside Core; the repository contract remains the planning queue, guardrails,
and validation commands.
Use `scripts\plan-local-codex.bat -Json -SummaryOnly` when another agent needs
compact evidence for optional local Codex config and localhost `llama-server`
endpoint readiness without mutating local setup. When `ofxGgmlLlama` metadata
declares a Codex smoke entrypoint, the plan also reports the lane-owned
`scripts\test-local-codex.bat -Json -SummaryOnly` follow-up. When the
Llama-owned planner is present, Core carries through its served-model and local
process evidence, including unavailable process inspection, so handoffs can see
whether the actual GGUF file behind the configured Codex model alias is known.
Keep experimental local-provider TOML quarantined until `codex exec` works with
tool-bearing features disabled through explicit `-c` overrides.
Use `scripts\check-ecosystem-readiness.bat` when you need a single
non-mutating readiness pass for Codex, Copilot, or Hermes Agent. It checks
agent instruction freshness, strict ecosystem audit status, planning handoffs,
structured JSON handoffs, doctor rollout status, merged branch cleanup
planning, and managed doctor smoke tests.
Use `scripts\check-ecosystem-readiness.bat -Json` when another agent needs
readiness `Summary` counts plus detailed `Steps` and `DoctorTests` evidence;
the embedded branch-cleanup step uses compact summary evidence so routine
handoffs do not include the full branch inventory.
Use `scripts\check-ecosystem-readiness.bat -Json -SummaryOnly` when another
agent needs compact readiness pass/fail evidence without embedding successful
step logs; failed step output is retained for diagnosis.
Use `scripts\audit-ecosystem.bat` when you need a compact readiness matrix for
agent instructions, reusable workflow coverage, validation, and release gates.
Use `scripts\audit-ecosystem.bat -Json` when another agent needs compact
audit `Summary` counts plus per-repository readiness actions.
Use `scripts\audit-ecosystem.bat -Strict -Json -SummaryOnly` when another
agent needs blocker counts and compact audit actions without full repository
rows.
Use `scripts\plan-doctor-rollout.bat` to plan which managed companion repos
need a focused doctor entry point, wrapper, smoke test, or validation hook.
Use `scripts\plan-doctor-rollout.bat -Json` when another agent needs doctor
coverage `Summary` counts, follow-up commands, and per-repository actions.
Use `scripts\plan-doctor-rollout.bat -Json -SummaryOnly` when another agent
needs compact doctor coverage evidence without full script lists.
Use `scripts\plan-backend-runtime-verification.bat -Json -SummaryOnly` when
another agent needs compact backend/runtime readiness evidence before choosing a
model-backed runtime smoke target. It reports declared CPU/CUDA/Metal/Vulkan
lanes, local model/build evidence, runtime-smoke entry points, and release
handoff actions without running inference or mutating companion addons.
Use `scripts\plan-release-readiness.bat` to generate a release-readiness score
with workflow-status evidence, backend capability evidence, backend runtime verification evidence,
and smoke-build CI evidence when planning release gates. By default it writes
to a temporary report path and folds in
`docs\backend-capability-report.md`, generated backend runtime planning, plus
`.smoke-build-ci-report.json` when present; pass `-OutputPath` when you
intentionally want to persist evidence in the repository.
Workflow-status reports include the active GitHub access mode and call out HTTP
429 rate-limit evidence explicitly; regenerate them with `GITHUB_TOKEN` or an
authenticated local `gh` before using them for a strict release gate.
Use `scripts\fetch-smoke-build-ci-report.bat -Force` when an agent needs to
download the latest uploaded smoke-build CI artifact into
`.smoke-build-ci-report.json`; this requires GitHub Actions artifact access
through `GITHUB_TOKEN`, `-Token`, or an authenticated local `gh` session.
Use `scripts\plan-release-readiness.bat -FetchSmokeBuildCiReport` when a CI or
release agent should fetch the smoke-build CI artifact into a temporary path and
fold it into the release-readiness score in one pass.
Use `scripts\plan-release-readiness.bat -Json` when another agent needs release
evidence `Summary` counts, generated report paths, evidence paths, and next
commands.
Use `scripts\plan-release-readiness.bat -Json -SummaryOnly` when another agent
needs compact release evidence summaries without generated report paths.
Use `scripts\assert-release-readiness.bat -SmokeBuildCiReport <path>` when a
release gate should fail on missing workflow/backend/runtime evidence, workflow
blockers, or failed smoke-build CI evidence.
Use `scripts\list-models.bat -Json -SummaryOnly` when another agent needs
compact model discovery `Summary` counts and search-directory existence before
planning model-backed smoke tests. Re-run without `-SummaryOnly` when nearby
GGUF file metadata is needed.
Use `scripts\plan-of-smoke-build.bat` to plan the next openFrameworks
project-generation and smoke-build rollout before adding compile gates.
Use `scripts\plan-of-smoke-build.bat -Json` when another agent needs smoke
build `Summary` counts, next commands, records, and target queues.
Use `scripts\select-smoke-build-target.bat -Stage generate-project` when an
agent needs the next concrete smoke-build target without parsing the full plan.
Use `scripts\select-smoke-build-target.bat -Stage generate-project -Json -SummaryOnly`
when another agent needs compact target selection `Summary` counts, next
commands, and target summaries.
Use `scripts\plan-smoke-build-target-handoff.bat -Stage generate-project` when
an agent needs the command, validation checklist, and artifact guardrails for
that selected target.
Use `scripts\plan-smoke-build-target-handoff.bat -Stage generate-project -Json -SummaryOnly`
when another agent needs compact handoff `Summary` counts and target summaries
without full command and guardrail lists.
Use `scripts\check-smoke-build-target-preflight.bat -Stage generate-project`
before running projectGenerator to confirm the selected repo is clean and the
target still matches filesystem state.
Use `scripts\check-smoke-build-target-preflight.bat -Stage generate-project -Json -SummaryOnly`
when another agent needs compact readiness `Summary` counts and gated next
commands.
Use `scripts\check-smoke-build-target-postflight.bat -Repository <addon> -Example <example>`
after running projectGenerator to report generated files, git impact, and next
validation without staging anything.
Use `scripts\check-smoke-build-target-postflight.bat -Repository <addon> -Example <example> -Json -SummaryOnly`
when another agent needs compact completion `Summary` counts, generated-file
counts, and review counts.
Use `scripts\plan-smoke-build-project-repair.bat -Repository <addon> -Example <example> -Json`
when another agent needs repair-state `Summary` counts, expected addon
references, and repair next commands.
Use `scripts\plan-smoke-build-compile.bat -Repository <addon> -Example <example> -Json`
when another agent needs compile-readiness `Summary` counts and focused next
commands.
The `smoke-build-ci` workflow writes `.smoke-build-ci-report.json` with top-level
`Summary` counts for release and agent handoff evidence.
Use `-Jobs 0` with `scripts\build-simple-example.bat`,
`scripts\build-smoke-example.bat`, or `scripts\plan-smoke-build-compile.bat`
to opt into all available MSBuild processors on Windows; omitting `-Jobs`
keeps the conservative serial build behavior.
Use `scripts\plan-agent-branch-cleanup.bat` after merged fanout PRs to list
merged `codex/*` branches that can be reviewed for cleanup without touching
classified legacy snapshots.
Use `scripts\plan-agent-branch-cleanup.bat -Json -SummaryOnly` when another
agent only needs cleanup `Summary` counts, per-repository counts, next commands,
and the safety note.

For Hermes Agent, Codex, and GitHub Copilot support, use
`scripts\write-agent-instructions.bat` to generate `HERMES.md`, `AGENTS.md`,
and `.github\copilot-instructions.md` across the active addon and workflow
repos.

## Validation

```powershell
.\scripts\validate-local.bat
```

Before tagging or publishing a release candidate:

```powershell
.\scripts\release-candidate.bat
```

On macOS/Linux:

```sh
./scripts/validate-local.sh
./scripts/release-candidate.sh
```

This checks addon headers, setup dry-runs, generated project repair, launch
dry-runs, first-run dry-runs, model listing, doctor output, and artifact hygiene.
