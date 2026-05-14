# Examples

`ofxGgmlCore` intentionally ships one example:

| Example | Purpose | Model |
| --- | --- | --- |
| `ofxGgmlCoreExample` | Smoke-test the addon, ggml runtime discovery, and ofxImGui integration | none |

Run it from the Core addon folder:

Windows:

```powershell
scripts\run-simple-example.bat -Build
```

macOS/Linux:

```sh
./scripts/run-simple-example.sh -Build
```

Text, chat, and embedding examples moved to `ofxGgmlLlama` so Core stays
backend-neutral:

Windows:

```powershell
cd ..\ofxGgmlLlama
scripts\run-example.bat text -Build -Model C:\path\to\model.gguf
scripts\run-example.bat chat -Build -Model C:\path\to\model.gguf
scripts\run-example.bat embedding -Build -Model C:\path\to\embedding-model.gguf
```

macOS/Linux:

```sh
cd ../ofxGgmlLlama
./scripts/run-example.sh text -Build -Model /path/to/model.gguf
./scripts/run-example.sh chat -Build -Model /path/to/model.gguf
./scripts/run-example.sh embedding -Build -Model /path/to/embedding-model.gguf
```

The Llama addon keeps the server lifecycle scripts, CLI fallback, and model
launch logic. Core examples should remain small enough to build without a model
or a model-specific runtime.
