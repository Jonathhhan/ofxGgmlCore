# ofxGgmlVideoEssayExample

Focused companion example extracted from the removed `ofxGgmlGuiExample` Video Essay / Long Video workflow.

## What it demonstrates

- `ofxGgmlVideoEssayWorkflow` request validation
- citation → outline → script → voice cue → SRT handoff shape
- workflow manifest and video/edit planning boundaries
- an opt-in full generation path that stays out of the main GUI example

## Requirements

- `ofxGgml`
- a local text model and llama.cpp executable when enabling full generation
- optional crawler setup for source discovery
- optional companion preview/render tools such as `ofxVlc4` in your own project

## Run

Open the project in openFrameworks or regenerate project files. The app starts in preview mode without requiring a model. Set `request.modelPath` in `src/ofApp.cpp`, then press `R` to run the full workflow.
