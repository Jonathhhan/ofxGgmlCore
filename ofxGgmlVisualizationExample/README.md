# ofxGgmlVisualizationExample

Focused companion example extracted from the removed `ofxGgmlGuiExample` MilkDrop workflow.

## What it demonstrates

- `ofxGgmlMilkDropGenerator::preparePrompt()`
- preset sanitization, validation, suggested filenames, and saving
- opt-in text-model generation for new `.milk` presets
- a clean boundary for optional `ofxProjectM` playback in downstream apps

## Requirements

- `ofxGgml`
- a local text model and llama.cpp executable when pressing `G` to generate
- optional `ofxProjectM` if your companion app wants live preset preview

## Run

The app opens with a seed preset and validation summary. Press `V` to revalidate, `S` to save a sanitized preset, or set `modelPath` in `src/ofApp.cpp` and press `G` to generate.
