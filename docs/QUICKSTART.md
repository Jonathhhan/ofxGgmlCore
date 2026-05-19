# Quick Start

## 1. Clone Beside openFrameworks

Put `ofxGgmlCore` in the openFrameworks `addons` folder:

```powershell
cd path\to\openFrameworks\addons
git clone https://github.com/Jonathhhan/ofxGgmlCore.git
```

For the Core example UI, also install `ofxImGui` beside it.

## 2. Setup Core

```powershell
cd ofxGgmlCore
.\scripts\first-run.bat
```

This sets up ggml and runs the doctor. It does not build llama.cpp or start any
model server.

To choose a backend explicitly:

```powershell
.\scripts\setup-ggml.bat -CpuOnly
.\scripts\setup-ggml.bat -Cuda
.\scripts\setup-ggml.bat -Vulkan
.\scripts\setup-ggml.bat -AllBackends
```

`-Auto` is the default.

`setup-ggml` rewrites the marked backend block in `addon_config.mk` to match
the locally built ggml libraries. Seeing `addon_config.mk` as modified after a
CUDA, Vulkan, or CPU-only setup is expected. Do not commit that local backend
selection unless intentionally changing the repository default.

On macOS/Linux, run scripts via `pwsh -File`:

```sh
pwsh -File scripts/first-run.ps1
pwsh -File scripts/setup-ggml.ps1 -CpuOnly
```

## 3. Run The Core Example

```powershell
.\scripts\run-simple-example.bat -Build
```

The example opens a small openFrameworks window showing Core runtime status.
No model required.

## 4. Run Llama Examples

Text, chat, and embedding examples live in `ofxGgmlLlama`:

```powershell
cd ..\ofxGgmlLlama
.\scripts\build-llama-server.bat
.\scripts\run-example.bat text -Build -Model C:\path\to\model.gguf
```

## 5. Validate

```powershell
.\scripts\validate-local.bat
```

Validation checks Core setup and example without requiring companion addons.