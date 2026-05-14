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

Use `scripts\plan-coding-agent-work.bat -OutputPath docs\CODING_AGENT_WORK.md`
to write a prioritized, agent-safe work queue. It is designed for Codex,
GitHub Copilot, and Hermes Agent sessions that need a next concrete task with
suggested files and validation commands.

Use `scripts\check-ecosystem-readiness.bat` for a single non-mutating pass
before broad ecosystem work. It checks generated agent instructions, strict
ecosystem audit status, planning handoffs, doctor rollout status, branch cleanup
planning, and managed doctor smoke tests.

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
legacy/reference siblings.

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
