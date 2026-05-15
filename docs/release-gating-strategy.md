# Release Gating Strategy

## Goal

Transition the ecosystem from policy-only release coordination toward operationally enforced release readiness.

## Current gating layer

The ecosystem currently provides:

- metadata validation
- baseline compatibility checks
- cross-repo metadata reconciliation
- release-readiness scoring
- live workflow observability scaffolding
- workflow action summaries folded into release-readiness evidence
- backend capability reports folded into release-readiness evidence
- backend runtime verification handoff evidence folded into release-readiness evidence
- multi-platform smoke-build scaffolding
- Core CPU backend runtime smoke evidence from the reusable `backend-runtime-check` workflow
- lane-owned runtime-smoke entrypoints across all managed runtime lanes

## Current limitations

Current release gates do not yet:

- validate cross-platform openFrameworks compilation and execution (Windows only in current CI smoke loop)
- require a smoke-build CI report artifact when `.smoke-build-ci-report.json` is absent
- validate model-backed runtime inference
- validate CUDA/Metal/Vulkan runtime availability in CI
- fully enforce build failures from the smoke-build CI control-plane in the release approval decision

## Planned release-gating phases

### Phase 1

Policy + metadata gates:

- metadata validation
- baseline compatibility
- release-readiness scoring
- reconciliation reports

### Phase 2

Operational workflow gates:

- required workflow success
- stale workflow detection
- missing smoke-build detection
- required blocker and optional rollout-gap evidence in release-readiness reports
- release-train blocking from failed workflows
- release-readiness score generated with workflow status evidence

### Phase 3

Compilation gates:

- example project generation
- example compilation
- addon_config.mk verification
- cross-platform compile validation

### Phase 4

Runtime gates:

- runtime initialization, starting with Core CPU backend smoke evidence
- lane-owned runtime smoke evidence across companion runtime lanes
- backend verification for optional GPU backends when suitable runners are available
- lightweight graph smoke tests
- model-backed inference startup

## Long-term direction

The ecosystem should eventually support:

- operational release trains
- autonomous release coordination
- compatibility enforcement from actual builds
- backend/runtime capability verification
- live ecosystem health scoring
- autonomous propagation gating
