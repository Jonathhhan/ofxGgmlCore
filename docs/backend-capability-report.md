# Backend Capability Report

Generated from Core metadata and local ggml runtime files.

| Backend | Declared support | Local runtime evidence | Inference smoke | Status |
| --- | --- | --- | --- | --- |
| `cpu` | yes | local library present | not checked | ready for runtime init smoke |
| `cuda` | yes | local library present | not checked | ready for runtime init smoke |
| `metal` | yes | not installed locally | not checked | optional backend absent |
| `vulkan` | yes | not installed locally | not checked | optional backend absent |
| `opencl` | yes | not installed locally | not checked | optional backend absent |

## Interpretation

- This is phase-1 backend discovery evidence, not a release-grade inference certificate.
- `local library present` means Core can see a built ggml backend artifact on this machine.
- `runtime smoke passed` means `scripts\build-runtime-smoke.ps1` initialized the backend and ran the lightweight graph smoke locally.
- Optional backend absence is reported without failing unrelated validation.
- Release gating still needs phase-2 runtime initialization and phase-3 inference smoke evidence.
