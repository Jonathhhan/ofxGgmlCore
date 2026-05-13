# GPU Runner Strategy

## Goal

Transition GPU backend support from declared capability toward operationally verified capability.

## Backend truth model

### CPU

CPU backend is the mandatory baseline.

Expected properties:

- runtime initialization succeeds
- lightweight inference smoke succeeds
- release gating may depend on CPU validation

### CUDA

CUDA backend validation requires:

- CUDA-enabled runner
- ggml CUDA build
- CUDA runtime availability
- optional lightweight inference smoke

### Metal

Metal backend validation requires:

- macOS runner
- ggml Metal build
- Metal runtime availability
- optional lightweight inference smoke

### Vulkan

Vulkan backend validation requires:

- Vulkan-capable environment
- Vulkan loader/runtime
- ggml Vulkan build
- optional lightweight inference smoke

## Hosted vs self-hosted runners

### GitHub-hosted runners

Useful for:

- structural CI
- CPU validation
- workflow orchestration
- metadata validation

Limited for:

- CUDA runtime truth
- Vulkan runtime truth
- stable GPU availability

### Self-hosted runners

Recommended for:

- CUDA validation
- Vulkan validation
- deterministic GPU runtime verification
- backend capability certification

## Future operational direction

The ecosystem should eventually support:

- backend-specific release gating
- runtime capability certification
- backend health dashboards
- operational compatibility truth
- autonomous runtime-aware release coordination
