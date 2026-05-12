# Examples

`ofxGgmlCore` intentionally ships one example:

| Example | Purpose | Model |
| --- | --- | --- |
| `ofxGgmlSimpleExample` | Smoke-test the addon, ggml runtime discovery, and ofxImGui integration | none |

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
scripts\run-text-example.bat -Build -Model C:\path\to\model.gguf
scripts\run-chat-example.bat -Build -Model C:\path\to\model.gguf
scripts\run-embedding-example.bat -Build -Model C:\path\to\embedding-model.gguf
```

macOS/Linux:

```sh
cd ../ofxGgmlLlama
./scripts/run-text-example.sh -Build -Model /path/to/model.gguf
./scripts/run-chat-example.sh -Build -Model /path/to/model.gguf
./scripts/run-embedding-example.sh -Build -Model /path/to/embedding-model.gguf
```

The Llama addon keeps the server lifecycle scripts, CLI fallback, and model
launch logic. Core examples should remain small enough to build without a model
or a model-specific runtime.
