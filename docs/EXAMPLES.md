# Examples

`ofxGgmlCore` intentionally ships one example:

| Example | Purpose | Model |
| --- | --- | --- |
| `ofxGgmlCoreExample` | Smoke-test addon, worker-thread runtime discovery, CPU/accelerator selection, verified tensor benchmark, ofxImGui | none |

Run it:

```powershell
.\scripts\run-simple-example.bat -Build
```

Text, chat, and embedding examples live in `ofxGgmlLlama`:

```powershell
cd ..\ofxGgmlLlama
.\scripts\run-example.bat text -Build -Model C:\path\to\model.gguf
```

Core examples stay small and build without a model or model-specific runtime.
The example owns its runtime and graph inside a dedicated `ofThread` worker;
the UI exchanges copied jobs and result snapshots through `ofThreadChannel`.
