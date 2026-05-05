# Optional NVIDIA NVIGI bridge helpers

`ofxGgml` does not vendor the NVIDIA NVIGI SDK, plugin binaries, or NVIGI
model data. Instead, the addon exposes small callback bridges that let an
application owning an NVIGI SDK integration plug those calls into the existing
ofxGgml request/result types.

Define `OFXGGML_ENABLE_NVIGI=1` in the application or project that wires the
SDK callbacks. When the flag is not defined, all NVIGI helpers remain available
for construction in direct includes, but calls return explicit disabled errors.

## Supported bridge surfaces

- `ofxGgmlNvigiGptBackend` for GPT/text generation callbacks.
- `ofxGgmlNvigiAsrSpeechBackend` for ASR/speech transcription callbacks.
- `ofxGgmlNvigiTtsBackend` for TTS/speech synthesis callbacks.
- `ofxGgmlNvigiRagBackend` for SDK-owned RAG retrieval and RAG generation.
- `ofxGgmlNvigiReloadController` for app-owned load, unload, reload, and
  refresh controls.

The callback approach keeps SDK lifetime, plugin selection, device selection,
model data paths, and reload semantics under application control while allowing
the rest of the addon to consume normal ofxGgml results.

## ASR Whisper guide wiring

NVIDIA's NVIGI ASR Whisper programming guide is the right reference for the
application-owned code that backs `ofxGgmlNvigiAsrSpeechBackend`. Keep the
guide-specific SDK initialization, plugin handles, model paths, and runtime
shutdown outside the addon, then pass a transcription callback into
`ofxGgmlSpeechInference::createNvigiAsrBackend()` or construct
`ofxGgmlNvigiAsrSpeechBackend` directly.

Map the addon request fields into the NVIGI Whisper ASR request owned by the
application:

- `audioPath` identifies the source audio to decode or load before submitting to
  NVIGI.
- `modelPath` or `ofxGgmlNvigiAsrSpeechBackend::Options::modelId` can select the
  Whisper model data known to the SDK integration.
- `languageHint`, `prompt`, and `task` should be forwarded when the selected
  NVIGI Whisper path supports language hints, initial prompts, transcription,
  or translation.
- `returnTimestamps` should request timestamp-capable output when the SDK/plugin
  path supports segments.

Map the NVIGI response back into `ofxGgmlSpeechResult`:

- set `success`, `text`, `detectedLanguage`, and `rawOutput` from the SDK
  response;
- fill `segments` with `ofxGgmlSpeechSegment` values when NVIGI returns
  timestamped ranges;
- copy SDK failures into `error` instead of throwing through the bridge.

The addon intentionally does not include NVIGI headers in this bridge. A project
that follows the guide should define `OFXGGML_ENABLE_NVIGI=1`, include the NVIGI
SDK in the application target, and keep SDK objects alive for as long as the
callback can be invoked.

## Layered includes

- `ofxGgmlBasic.h` exposes NVIGI GPT and reload helpers when
  `OFXGGML_ENABLE_NVIGI=1`.
- `ofxGgmlModalities.h` exposes NVIGI ASR and TTS helpers when
  `OFXGGML_ENABLE_NVIGI=1`.
- `ofxGgmlWorkflows.h` exposes the NVIGI RAG helper when
  `OFXGGML_ENABLE_NVIGI=1`.

Direct includes are also supported:

```cpp
#include "inference/ofxGgmlNvigiGptBackend.h"
#include "inference/ofxGgmlNvigiSpeechBackend.h"
#include "inference/ofxGgmlNvigiTtsBackend.h"
#include "inference/ofxGgmlNvigiRagBackend.h"
#include "inference/ofxGgmlNvigiReloadController.h"
```

## Notes

- The bridges intentionally avoid including NVIGI headers so the default addon
  build remains portable.
- Applications should initialize, validate, and shut down the NVIGI runtime
  outside these bridge objects.
- Applications should map SDK-specific errors into the `error` fields on the
  corresponding ofxGgml result types.
- Reload callbacks should decide whether a component reload preserves session
  state, refreshes model data, unloads plugin state, or rebuilds the SDK
  pipeline.
