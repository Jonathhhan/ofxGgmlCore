# AceStep Models

Place AceStep-compatible GGUF model files in:

```text
models/acestep/gguf
```

The addon does not ship these model files. The AceStep bridge expects an external AceStep-compatible server to load the required LM, text encoder, DiT, and VAE GGUF assets from this directory or from the server's own configured model path.
