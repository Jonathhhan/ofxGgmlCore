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
- multi-platform smoke-build scaffolding

## Current limitations

Current release gates do not yet:

- validate real openFrameworks compilation
- validate runtime inference
- validate CUDA/Metal/Vulkan runtime availability
- validate generated project execution
- block releases from actual failed CI state

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
- release-train blocking from failed workflows

### Phase 3

Compilation gates:

- example project generation
- example compilation
- addon_config.mk verification
- platform-specific compile validation

### Phase 4

Runtime gates:

- runtime initialization
- backend verification
- lightweight inference startup
- runtime smoke tests

## Long-term direction

The ecosystem should eventually support:

- operational release trains
- autonomous release coordination
- compatibility enforcement from actual builds
- backend/runtime capability verification
- live ecosystem health scoring
- autonomous propagation gating
