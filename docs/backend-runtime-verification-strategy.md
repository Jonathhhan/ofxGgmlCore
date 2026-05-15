# Backend Runtime Verification Strategy

## Goal

Transition the ecosystem from declared backend support toward validated backend/runtime support.

## Current state

The ecosystem currently provides:

- backend declarations in `ofxggml-addon.json`
- metadata validation
- compatibility enforcement scaffolding
- multi-platform smoke-build scaffolding
- release-gating scaffolding
- CPU backend runtime smoke checks through `backend-runtime-check`
- lightweight ggml graph compute/readback validation on Windows and Ubuntu CI

Current workflows validate Core CPU backend availability for relevant runtime
changes. Optional GPU backends are still reported or validated locally, not yet
certified by shared CI runners.

Core now generates a phase-1 backend capability report from declared metadata and
local ggml runtime artifacts. This report is discovery evidence only; it does
not replace model-backed inference smoke checks.

## Planned verification phases

### Phase 1

Backend discovery:

- CPU backend detection
- CUDA runtime discovery
- Metal runtime discovery
- Vulkan runtime discovery
- optional backend reporting
- status: active for CPU, planned for GPU backends in CI

### Phase 2

Backend initialization:

- minimal ggml context allocation
- runtime initialization without model files
- backend capability report generation
- status: active for Core CPU runtime smoke on Windows and Ubuntu

### Phase 3

Inference smoke tests:

- tiny fixture model loading
- minimal inference execution
- runtime success/failure reporting
- backend-specific smoke validation
- status: planned; current runtime smoke covers graph compute/readback without model files

### Phase 4

Operational enforcement:

- release gating from backend verification
- capability validation against actual runtime
- backend health observability
- backend-specific release readiness scoring

## Design constraints

- CPU backend should remain mandatory baseline.
- GPU backends should be optional unless explicitly required.
- Missing optional backends should not fail unrelated workflows.
- Runtime failures should distinguish environment problems from unsupported hardware.

## Long-term direction

The ecosystem should eventually support:

- backend capability truthfulness
- runtime-backed compatibility enforcement
- operational release gating
- backend observability dashboards
- autonomous runtime-aware release coordination
