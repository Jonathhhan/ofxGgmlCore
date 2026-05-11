# Segmentation And SAM3

`ofxGgmlSegmentation.h` is the public segmentation boundary. It intentionally
stays small: point prompts in, masks out. SAM/SAM3 model integration should move
to the companion addon `ofxGgmlSam`; this core addon keeps only the small
boundary and temporary optional SAM3 adapter hooks. Include `ofxGgmlSam3.h` only
in projects that need the current concrete SAM3 adapter helpers.

## Current Decision

Do not add an openFrameworks segmentation example yet.

The segmentation API is test-covered and script-smoked, but a useful GUI example
belongs in `ofxGgmlSam` once there is a real model/image workflow:

- a known-compatible SAM3 GGUF model path
- a small sample image that can be redistributed or generated locally
- clear expected behavior for CPU and GPU runs
- an interaction that demonstrates masks, not just adapter setup

Until those are available, the script smoke path is the correct example. It
keeps the optional adapter honest without making the default addon feel broken
for users who have not installed SAM3.

## Smoke Path

First verify the public boundary without a SAM3 model:

```bat
scripts\test-sam3-smoke.bat
```

After installing and building the optional adapter, run a model smoke:

```bat
scripts\install-sam3-cpp.bat
scripts\build-sam3-cpp.bat -Cuda -SkipExamples
scripts\test-sam3-smoke.bat -ModelPath C:\path\to\sam3-model.gguf
```

The model smoke builds a tiny generated RGB image in memory and submits one
positive point prompt. It is not a quality test; it only proves that the adapter
can load, encode an image, and return either masks or a clear runtime error.

## Example Gate

Add `ofxGgmlSegmentationExample` only when all of these are true:

- the smoke path succeeds with a known model on at least one local machine
- the example can load a user-selected image and model path
- missing model/image states are useful rather than noisy
- mask preview is visible and deterministic enough for manual verification
- the example does not require committed model binaries or downloaded assets

When the gate is met, build the example in `ofxGgmlSam`. It should use
`ofxImGui` like the companion examples, and it should remain focused on one
point-prompt mask flow.
