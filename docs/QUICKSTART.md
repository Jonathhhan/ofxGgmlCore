# Quick Start

## 1. Clone Beside openFrameworks

Put `ofxGgmlCore` in the openFrameworks `addons` folder:

```powershell
cd C:\path\to\openFrameworks\addons
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

## 3. Run The Core Example

```powershell
.\scripts\run-simple-example.bat -Build
```

The example should open a small openFrameworks window and show Core runtime
status. It does not need a model.

## 4. Run Llama Examples

Text, chat, and embedding examples live in `ofxGgmlLlama`:

```powershell
cd ..\ofxGgmlLlama
.\scripts\build-llama-server.bat
.\scripts\run-text-example.bat -Build -Model C:\path\to\model.gguf
.\scripts\run-chat-example.bat -Build -Model C:\path\to\model.gguf
.\scripts\run-embedding-example.bat -Build -Model C:\path\to\embedding-model.gguf
```

That addon owns llama.cpp tools, server lifecycle, CLI fallback, and Llama model
paths.

## 5. Validate

```powershell
.\scripts\validate-local.bat
```

Validation checks the Core setup and example without requiring model-specific
companions.
