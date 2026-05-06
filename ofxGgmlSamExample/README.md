# ofxGgmlSamExample

Focused point-prompt segmentation example for `ofxGgmlSegmentationInference`.

The app loads `bin/data/images/sam-input.png` when present, otherwise it creates a generated fallback image. Click the image to place a positive point prompt, then press `S` to run segmentation and draw the first returned mask as a cyan overlay.

## Real SAM backends

The newer optional path is `sam3.cpp`, which supports SAM 2, SAM 2.1, SAM 3, and EdgeTAM GGML models. On Windows with CUDA Toolkit and Visual Studio CUDA integration installed:

```bat
..\scripts\install-sam3-cpp.bat
..\scripts\build-sam3-cpp.bat -Cuda
```

The installer patches the upstream checkout so `sam3.cpp` initializes ggml's CUDA backend before falling back to CPU. A CPU-only build is also available:

```bat
..\scripts\build-sam3-cpp.bat -CpuOnly
```

This example still defaults to the deterministic preview backend until the openFrameworks-facing `sam3.cpp` adapter is wired into the project link settings.

## Legacy sam.cpp backend

Install the optional `sam.cpp` checkout:

```bat
..\scripts\install-sam-cpp.bat
```

The checkout is not compiled automatically because the pinned `sam.cpp` source uses older ggml allocator APIs than the addon-local ggml `.11.0` build. The example stays on its deterministic preview backend by default.

To opt into a real backend, build or vendor a ggml `.11.0`-compatible Segment Anything implementation, define `OFXGGML_ENABLE_SAMCPP_ADAPTER=1`, link that implementation into your app, and place a converted Segment Anything model at:

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
