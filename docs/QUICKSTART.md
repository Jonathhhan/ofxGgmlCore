# Quick Start

## 1. Clone Beside openFrameworks

Put `ofxGgmlCore` in the openFrameworks `addons` folder:

Windows:

```powershell
cd C:\path\to\openFrameworks\addons
git clone https://github.com/Jonathhhan/ofxGgmlCore.git
```

macOS/Linux:

```sh
cd /path/to/openFrameworks/addons
git clone https://github.com/Jonathhhan/ofxGgmlCore.git
```

For the Core example UI, also install `ofxImGui` beside it.

## 2. Setup Core

Windows:

```powershell
cd ofxGgmlCore
.\scripts\first-run.bat
```

macOS/Linux:

```sh
cd ofxGgmlCore
./scripts/first-run.sh
```

This sets up ggml and runs the doctor. It does not build llama.cpp or start any
model server.

To choose a backend explicitly:

Windows:

```powershell
.\scripts\setup-ggml.bat -CpuOnly
.\scripts\setup-ggml.bat -Cuda
.\scripts\setup-ggml.bat -Vulkan
.\scripts\setup-ggml.bat -AllBackends
```

macOS/Linux:

```sh
./scripts/setup-ggml.sh -CpuOnly
./scripts/setup-ggml.sh -Cuda
./scripts/setup-ggml.sh -Vulkan
./scripts/setup-ggml.sh -AllBackends
```

`-Auto` is the default.

`setup-ggml` rewrites the marked backend block in `addon_config.mk` to match
the locally built ggml libraries. Seeing `addon_config.mk` as modified after a
CUDA, Vulkan, or CPU-only setup is expected. Do not commit that local backend
selection unless you are intentionally changing the repository default.

## 3. Run The Core Example

Windows:

```powershell
.\scripts\run-simple-example.bat -Build
```

macOS/Linux:

```sh
./scripts/run-simple-example.sh -Build
```

The example should open a small openFrameworks window and show Core runtime
status. It does not need a model.

## 4. Run Llama Examples

Text, chat, and embedding examples live in `ofxGgmlLlama`:

Windows:

```powershell
cd ..\ofxGgmlLlama
.\scripts\build-llama-server.bat
.\scripts\run-text-example.bat -Build -Model C:\path\to\model.gguf
.\scripts\run-chat-example.bat -Build -Model C:\path\to\model.gguf
.\scripts\run-embedding-example.bat -Build -Model C:\path\to\embedding-model.gguf
```

macOS/Linux:

```sh
cd ../ofxGgmlLlama
./scripts/build-llama-server.sh
./scripts/run-text-example.sh -Build -Model /path/to/model.gguf
./scripts/run-chat-example.sh -Build -Model /path/to/model.gguf
./scripts/run-embedding-example.sh -Build -Model /path/to/embedding-model.gguf
```

That addon owns llama.cpp tools, server lifecycle, CLI fallback, and Llama model
paths.

## 5. Validate

Windows:

```powershell
.\scripts\validate-local.bat
```

macOS/Linux:

```sh
./scripts/validate-local.sh
```

Validation checks the Core setup and example without requiring model-specific
companions.
