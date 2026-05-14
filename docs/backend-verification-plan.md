# Backend Verification Plan

This document defines how declared backend support should become validated backend support.

## Verification levels

| Level | Meaning |
| --- | --- |
| declared | Listed in `ofxggml-addon.json` |
| build-checked | CI compiled code paths for the backend |
| runtime-checked | Backend initialization succeeds in CI or local validation |
| inference-checked | A minimal model/inference smoke test succeeds |

## Repository backend validation targets

| Repository | Lane | Backend validation target | Current status |
| --- | --- | --- | --- |
| `Jonathhhan/ofxGgmlCore` | `core` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlLlama` | `text-chat-embeddings` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlAudio` | `audio` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlVision` | `vision` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlDiffusion` | `image-generation` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlSam` | `segmentation` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlMusic` | `music` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlRag` | `retrieval` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlAgents` | `agents` | from `ofxggml-addon.json` | planned |
| `Jonathhhan/ofxGgmlVideo` | `video` | from `ofxggml-addon.json` | planned |

## Initial runtime checks

- verify backend discovery commands/scripts exist
- verify CPU backend can initialize without model files
- verify optional GPU backends are reported as available/unavailable without failing the whole workflow
- separate hard failures from optional backend absence

## Future runtime checks

- minimal ggml context allocation
- CPU inference smoke test with tiny fixture
- CUDA runtime discovery
- Metal runtime discovery on macOS
- Vulkan runtime discovery where available
- backend capability report uploaded as CI artifact