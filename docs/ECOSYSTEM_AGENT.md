# ofxGgml Ecosystem Agent

This document defines the planning agent layer for the ofxGgml family. It is
for Codex, GitHub Copilot, Hermes Agent, and similar coding assistants working
across the addon ecosystem.

The ecosystem agent is not an addon runtime. Its job is to improve planning,
repository hygiene, release readiness, and cross-repository coordination before
any source-code work starts.

## Scope

The agent layer owns:

- repository instruction files: `HERMES.md`, `AGENTS.md`, and
  `.github/copilot-instructions.md`
- reusable GitHub Actions checks in `ofxGgmlWorkflows`
- ecosystem status and planning scripts
- documentation that explains addon boundaries, validation, and release gates

The agent layer does not own:

- C++ runtime behavior
- addon public APIs
- generated openFrameworks project files
- model files, downloaded runtimes, caches, or media outputs

Do not edit addon source from the agent layer unless the user explicitly asks
for addon behavior.

## Planning Loop

Before changing addon code, an agent should:

1. Read the repository instruction file for the active assistant.
2. Run or inspect `scripts/status-family.*` from `ofxGgmlCore`.
3. Generate an ecosystem plan with `scripts/plan-ecosystem.*`.
4. Generate a prioritized work queue with `scripts/plan-coding-agent-work.*`.
5. Classify the work as documentation, automation, validation, or addon code.
6. Touch addon source only when the user explicitly asks for addon behavior.
7. Report the plan, touched repositories, and validation commands.

## Commands

From `ofxGgmlCore`:

```powershell
scripts\status-family.bat
scripts\audit-ecosystem.bat
scripts\check-ecosystem-readiness.bat
scripts\plan-ecosystem.bat
scripts\plan-coding-agent-work.bat
scripts\plan-doctor-rollout.bat
scripts\plan-agent-branch-cleanup.bat
scripts\write-agent-instructions.bat -Check
```

On macOS/Linux:

```sh
./scripts/status-family.sh
./scripts/audit-ecosystem.sh
./scripts/check-ecosystem-readiness.sh
./scripts/plan-ecosystem.sh
./scripts/plan-coding-agent-work.sh
./scripts/plan-doctor-rollout.sh
./scripts/plan-agent-branch-cleanup.sh
./scripts/write-agent-instructions.sh -Check
```

Use `scripts\plan-ecosystem.bat -OutputPath docs\ECOSYSTEM_PLAN.md` to write a
handoff plan for review.
Use `scripts\status-family.bat -Json` when Codex, GitHub Copilot, Hermes Agent,
or another automation needs local inventory `Summary` counts, next commands,
and per-repository status before choosing a planning command. Its next commands
include compact ecosystem, readiness, and branch-cleanup summary evidence, not
branch deletion.
Use `scripts\status-family.bat -Json -SummaryOnly` when another agent needs
local inventory counts and compact repository summaries without the full addon
records.
Use `scripts\plan-ecosystem.bat -Json` when Codex, GitHub Copilot, Hermes Agent,
or another automation needs machine-readable `Summary`, `PlanningPriorities`,
`AgentGuardrails`, `SmokeBuildLifecycle`, and `SuggestedValidation` fields
without parsing Markdown.
Use `scripts\plan-ecosystem.bat -Json -SummaryOnly` when another agent needs
those fields plus compact repository summaries without embedding the full addon
inventory. The `SuggestedValidation` list uses compact ecosystem and branch
cleanup JSON commands so routine handoffs stay small.

Use `scripts\plan-coding-agent-work.bat -OutputPath docs\CODING_AGENT_WORK.md`
to write a prioritized, agent-safe work queue. It is designed for Codex,
GitHub Copilot, and Hermes Agent sessions that need a next concrete task with
suggested files and validation commands.
Use `scripts\plan-coding-agent-work.bat -Json` when an agent needs structured
queue summary data plus per-task `SuggestedFileList` and `ValidationCommands`
arrays instead of parsing the Markdown table. The JSON output also includes the
same `Guardrails` list shown in Markdown.
Use `scripts\audit-ecosystem.bat -Json` when another agent needs compact audit
`Summary` counts plus per-repository readiness actions before deciding whether
to run the broader readiness pass.
Use `scripts\audit-ecosystem.bat -Strict -Json -SummaryOnly` when another agent
needs blocker counts and compact audit actions without full repository rows.
Use `scripts\plan-doctor-rollout.bat -Json` when another agent needs doctor
coverage `Summary` counts, follow-up commands, and per-repository actions.
Use `scripts\plan-doctor-rollout.bat -Json -SummaryOnly` when another agent
needs compact doctor coverage evidence without full script lists.

The latest committed queue snapshot lives at `docs\CODING_AGENT_WORK.md`.
Follow-up control-plane planning lives at `docs\CONTROL_PLANE_NEXT_STEPS.md`.

The coding-agent queue auto-detects completed planning guides. Companion lanes
with `docs\*_WORKFLOWS.md`, Core with `docs\ECOSYSTEM_AGENT.md`, and
`ofxGgmlWorkflows` with `docs\workflow-adoption.md` are listed as completed
planning coverage instead of being repeatedly proposed as generic lane-uplift
tasks.

Use `scripts\check-ecosystem-readiness.bat` for a single non-mutating pass
before broad ecosystem work. It checks generated agent instructions, strict
ecosystem audit status, planning handoffs, coding-agent work queue generation,
structured JSON handoffs, workflow guide coverage, doctor rollout status,
branch cleanup planning, and managed doctor smoke tests.
Use `scripts\check-ecosystem-readiness.bat -Json` when another agent needs
compact `Summary` counts plus detailed `Steps` and `DoctorTests` evidence.
Use `scripts\check-ecosystem-readiness.bat -Json -SummaryOnly` when another
agent needs pass/fail counts and step states without successful step logs.
Use `scripts\plan-release-readiness.bat -Json` when another agent needs release
evidence `Summary` counts, generated report paths, evidence paths, and next
commands before deciding whether CI truth is strong enough for a release gate.
Use `scripts\plan-release-readiness.bat -Json -SummaryOnly` when another agent
needs compact release evidence summaries without generated report paths.
Use `scripts\plan-backend-runtime-verification.bat -Json -SummaryOnly` when
another agent needs compact CPU/CUDA/Metal/Vulkan declaration, model-path,
example-build, runtime-smoke, and reference-lane readiness evidence before
choosing a model-backed runtime smoke target. Keep the first reference lane on
`ofxGgmlSam` until SAM3 CPU/CUDA runtime smoke evidence is lane-owned.
Use `scripts\plan-release-readiness.bat -SmokeBuildCiReport <path>` when an
agent has downloaded `.smoke-build-ci-report.json` from GitHub Actions and needs
generated-project compile evidence in the release readiness report.
Use `scripts\list-models.bat -Json -SummaryOnly` when another agent needs
compact model discovery `Summary` counts and search-directory existence before
planning model-backed smoke tests. Re-run without `-SummaryOnly` when nearby
GGUF file metadata is needed.

## Smoke-Build Target Lifecycle

Use the Core smoke-build control plane before any agent runs projectGenerator:

```powershell
scripts\plan-of-smoke-build.bat
scripts\select-smoke-build-target.bat -Stage generate-project
scripts\plan-smoke-build-target-handoff.bat -Stage generate-project
scripts\check-smoke-build-target-preflight.bat -Stage generate-project
scripts\check-smoke-build-target-postflight.bat -Stage generate-project
scripts\plan-smoke-build-project-repair.bat -Stage verify-generated-project
scripts\plan-smoke-build-compile.bat -Stage compile-example
scripts\build-smoke-example.bat -Repository ofxGgmlSam -Example ofxGgmlSamPointExample
```

On macOS/Linux:

```sh
./scripts/plan-of-smoke-build.sh
./scripts/select-smoke-build-target.sh -Stage generate-project
./scripts/plan-smoke-build-target-handoff.sh -Stage generate-project
./scripts/check-smoke-build-target-preflight.sh -Stage generate-project
./scripts/check-smoke-build-target-postflight.sh -Stage generate-project
./scripts/plan-smoke-build-project-repair.sh -Stage verify-generated-project
./scripts/plan-smoke-build-compile.sh -Stage compile-example
./scripts/build-smoke-example.sh -Repository ofxGgmlSam -Example ofxGgmlSamPointExample
```

Use `scripts\plan-of-smoke-build.bat -Json` when another agent needs smoke-build
`Summary` counts, next commands, records, and target queues before choosing a
focused target.
Use `scripts\select-smoke-build-target.bat -Stage generate-project -Json -SummaryOnly`
when another agent needs compact target selection `Summary` counts, next
commands, and target summaries.
Use `scripts\plan-smoke-build-target-handoff.bat -Stage generate-project -Json -SummaryOnly`
when another agent needs compact handoff `Summary` counts and target summaries
without full command and guardrail lists.
Use the `-Json -SummaryOnly` preflight and postflight outputs when Codex, GitHub
Copilot, or Hermes needs compact readiness and completion counts without nested
target arrays. Use the full `-Json` repair and compile planner outputs when an
agent needs repair-state detail and compile-readiness Summary counts.
Run projectGenerator only after preflight reports the selected target is ready.
After acting on a target, run postflight with the selected repository and
example if needed. When postflight reports missing Visual Studio addon wiring,
run the repair planner before compile validation. Review the dry-run first, then
use `-Apply` only for generated Visual Studio project metadata. Use the compile
planner for focused build handoff after postflight is OK, then run the emitted
addon-owned or generic build command for the selected target. Do not commit generated
project files unless that addon intentionally tracks them.

Use `scripts\audit-ecosystem.bat` to inspect whether managed and detected
repositories have current agent instructions, coding-agent workflow coverage,
validation entry points, and release gates.

Use `scripts\plan-doctor-rollout.bat` to plan consistent local diagnostics
across managed addon repositories. It reports which repos already have doctor
entry points, wrappers, smoke tests, and validation hooks, then recommends a
focused rollout order.

Use `scripts\plan-agent-branch-cleanup.bat` after merged Codex, Copilot, or
Hermes fanout PRs. It only writes a cleanup plan for merged agent branches in
managed repositories; it does not delete branches or operate on classified
legacy/reference siblings. The plan also reports matching local and remote
agent branch inventory so stale unmerged branches are visible before deletion
is considered. Cleanup candidates can be directly `merged` or
`patch-equivalent` when a squash merge already put the same patch on the
default branch.
Use `scripts\plan-agent-branch-cleanup.bat -Json -SummaryOnly` when another
agent needs only cleanup Summary counts, per-repository counts, next commands,
and the safety note; use the full plan before actually deleting branches.

## Auto-Discovery

The managed repository map lives in `docs/ECOSYSTEM_MANIFEST.json`. The agent
scripts use `scripts/get-ecosystem.ps1` to combine that known lane metadata
with auto-detected sibling repositories named `ofxGgml*`. Known repos keep
stable lane and scope text; new sibling repos are included with fallback
metadata so agents can see them, but should classify them before broad
automation changes.

Instruction generation updates known repositories by default. Use
`write-agent-instructions.* -IncludeDiscovered` only after confirming a new
sibling belongs in the managed ecosystem.

Detected legacy siblings are also classified in the manifest. The current
classified set points at old `ofxGgml` monorepo clones and local scratch
snapshots. Agents may use those directories as migration references, but should
not generate instructions, workflows, release gates, or broad automation there
unless a repository is intentionally promoted into the managed list.

## Planning Priorities

When priorities conflict, prefer work in this order:

1. Keep repository boundaries explicit for agents.
2. Keep validation cheap and repeatable.
3. Improve one backend lane until it is useful before widening all lanes.
4. Move shared helpers into `ofxGgmlCore` only after they are stable,
   domain-neutral, dependency-light, and tested.
5. Keep generated artifacts out of git.
