# ofxGgmlSamExample

Focused point-prompt segmentation example for `ofxGgmlSegmentationInference`.

The app loads `bin/data/images/sam-input.png` when present, otherwise it creates a generated fallback image. Click the image to place a positive point prompt, then press `S` to run segmentation and draw the first returned mask as a cyan overlay.

## Real sam.cpp backend

Install the optional `sam.cpp` checkout:

```bat
..\scripts\install-sam-cpp.bat
```

The checkout is not compiled automatically because the pinned `sam.cpp` source uses older ggml allocator APIs than the addon-local ggml `.11.0` build. The example stays on its deterministic preview backend by default.

To opt into a real backend, build or vendor a ggml `.11.0`-compatible SAM implementation, define `OFXGGML_ENABLE_SAMCPP_ADAPTER=1`, link that implementation into your app, and place a converted SAM model at:

```text
bin/data/models/sam/ggml-model-f16.bin
```

When the adapter macro, compatible `sam.h` symbols, and that model are present, the example attaches `ofxGgmlSamCppAdapters::createBackend(...)`. Otherwise it uses a deterministic preview backend so the example still builds and demonstrates the request/mask handoff.

## Controls

- Click: move the positive point prompt
- `S`: run segmentation
- `C`: clear mask
- `O`: reload the default image
- Drop image file: use it as the source image
