# Runtime Provider Manifest

`ofxGgmlCore` exposes a small script-level provider manifest so companion
addons can discover the local ggml runtime without taking a model-specific
dependency on Core internals.

```powershell
scripts\runtime-provider-manifest.ps1
scripts\runtime-provider-manifest.ps1 -Json
scripts\runtime-provider-manifest.ps1 -Json -SummaryOnly
scripts\runtime-provider-manifest.ps1 -Strict
scripts\runtime-provider-manifest.ps1 -Json > before.json
scripts\compare-runtime-provider-manifest.ps1 -BaselinePath before.json
scripts\compare-runtime-provider-manifest.ps1 -BaselinePath before.json -CurrentPath after.json -Json
scripts\compare-runtime-provider-manifest.ps1 -BaselinePath before.json -Strict
```

The manifest reports:

- Core root path
- ggml include and library directories
- staged ggml library paths
- enabled CPU/CUDA/Vulkan/Metal/OpenCL backend state
- normalized backend readiness states for scripting
- model-free readiness checks for companion addons
- optional ggml upstream release/commit pin evidence when available

Companion addons should use this as discovery evidence only. They still own
their model-specific setup, runtime policy, examples, and doctor output.

Core remains model-agnostic: this manifest must not grow diffusion, llama,
audio, vision, or other workflow-specific fields.

## Manifest Diffs

Use `compare-runtime-provider-manifest.ps1` to compare a saved manifest against
the current machine, or against another saved manifest. This is useful after
running setup, changing backend flags, moving a checkout, or handing runtime
evidence to a companion addon.

The diff reports:

- added or removed backend availability
- changed ggml include/source/library paths
- changed staged library paths
- changed vendor release or commit pin evidence
- changed readiness checks
- changed normalized backend readiness states
- changed companion readiness state

`-Json` emits the full machine-readable diff. `-SummaryOnly` emits counts only.
`-Strict` exits non-zero when any manifest change is detected, which is useful
for CI checks that intentionally pin the local runtime provider shape.
