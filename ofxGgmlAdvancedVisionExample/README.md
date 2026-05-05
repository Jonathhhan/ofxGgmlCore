# ofxGgmlAdvancedVisionExample

Focused companion example extracted from the removed `ofxGgmlGuiExample` Diffusion/CLIP, SAM, and Image Search panels.

## What it demonstrates

- CLIP-style image ranking through `ofxGgmlClipInference`
- Wikimedia reference-image search through `ofxGgmlImageSearch`
- point-prompt segmentation through `ofxGgmlSegmentationInference`
- diffusion request validation and bridge dispatch through `ofxGgmlDiffusionInference`

## Requirements

- `ofxGgml`
- optional `ofxStableDiffusion` adapter for real generation
- optional `sam.cpp` adapter for real segmentation
- network access only when pressing `W` for Wikimedia search

## Run

The app installs deterministic mock bridge backends so it can demonstrate the handoff contracts without external runtimes. Press `C` for CLIP ranking, `M` for segmentation, `D` for diffusion validation/dispatch, or `W` for optional network image search.
