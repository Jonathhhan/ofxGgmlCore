# openFrameworks Smoke Build Strategy

## Goal

Evolve the ecosystem from structural CI validation toward real openFrameworks example compilation validation.

## Current state

The ecosystem currently provides:

- multi-platform smoke-build scaffolding
- metadata validation
- baseline compatibility enforcement
- live workflow observability scaffolding

Current smoke workflows now include pull-request gated smoke compile validation for generated
projects via Core-owned generic compile handoff.

Use `scripts\plan-of-smoke-build.bat` from Core to generate the current
non-mutating rollout plan before adding project-generation or compile gates.
The planner now verifies that managed root-level examples expose the minimal
`addons.make` metadata needed by projectGenerator: the example must list its
owning addon and `ofxGgmlCore`.
When projectGenerator is available in the openFrameworks checkout, the planner
also emits a non-mutating command plan and reports which examples already have
generated project files.
It also emits a prioritized target queue so agents can work through metadata
repair, project generation, and generated-project verification in a deterministic
order.
Use `scripts\select-smoke-build-target.bat` to read the next target from that
queue without parsing the full plan output.
Use `scripts\plan-smoke-build-target-handoff.bat` when Codex, Copilot, or
Hermes needs the selected target plus validation and artifact hygiene steps.
Use `scripts\check-smoke-build-target-preflight.bat` immediately before acting
on a selected target to verify projectGenerator detection, example metadata,
repository cleanliness, and generated-project state.
Use `scripts\check-smoke-build-target-postflight.bat` after acting on a target
to report generated project files, pending git impact, and the validation
commands that should run before any handoff. The postflight distinguishes
generated Visual Studio project files that merely exist from projects that
actually reference the expected owner and companion addons.
Use `scripts\plan-smoke-build-project-repair.bat` when postflight reports
missing Visual Studio addon wiring; it produces a non-mutating repair plan with
the expected owner and companion addon references plus the next validation
commands. After reviewing that dry-run, `-Apply` can update generated Visual
Studio project metadata, followed by postflight and artifact hygiene.
Use `scripts\plan-smoke-build-compile.bat` after postflight is OK to turn
generated-project verification into focused example build commands without
running those builds automatically. For examples without an addon-owned build
script, the planner falls back to `scripts\build-smoke-example.bat`, a Core-owned
generic builder that refuses to run until generated-project postflight is
complete.

Current Windows projectGenerator evidence: Core now prefers the embedded
command-line generator at `projectGenerator\resources\app\app\projectGenerator.exe`
when present and emits Visual Studio commands with `-p'vs'`. Local project
generation writes usable Visual Studio files but returns a crash-style process
exit during addon processing, before addon include and library settings are
fully written. Core postflight reports those projects as incomplete until the
generated-project repair planner is applied.

The generated-project repair planner now restores expected owner, Core, and
ofxImGui Visual Studio references, plus addon `ADDON_CFLAGS` and `ADDON_LIBS`
metadata needed for linking Core ggml symbols from companion examples. Local
validation has generated and repaired all 14 managed addon examples while
leaving every owning addon worktree clean because generated project files remain
ignored.

Focused local compile evidence now covers all 14 managed examples on Windows
Release x64: Core simple; Llama text/chat/embedding; Audio transcribe; Sam point;
Vision image; Rag search; Video frame; Music analysis/generation; Diffusion
GAN/prompt; and Agents planner. Each completed with 0 errors; current warning
counts are ordinary openFrameworks/ofxImGui/compiler warnings and remain outside
the release gate.

## Planned smoke-build phases

### Phase 1

Structural validation only:

- repository structure
- examples directory presence
- workflow inheritance
- metadata validation

### Phase 2

Project generation validation:

- install openFrameworks
- verify root-level example `addons.make` metadata before project generation
- generate a command plan for each root-level smoke example
- follow the generated target queue for one focused example at a time
- run projectGenerator
- generate example projects
- verify generated project structure
- plan generated-project repair when Visual Studio addon wiring is incomplete
- plan focused compile targets after generated-project postflight is OK
- run generic focused compile validation for complete generated projects that do not yet own addon-local build scripts
- keep generated project files out of git unless a repository explicitly owns them

### Phase 3

Compilation validation:

- compile minimal examples
- validate addon_config.mk integration
- validate include/source paths
- validate platform-specific project generation

### Phase 4

Runtime smoke tests:

- minimal inference startup
- backend initialization
- lightweight model loading
- CPU runtime verification
- optional CUDA/Metal/Vulkan verification

## Long-term direction

The ecosystem should eventually support:

- backend capability verification
- compatibility enforcement from real builds
- release gating from operational truth
- ecosystem-wide runtime health visibility
- autonomous release-train coordination
