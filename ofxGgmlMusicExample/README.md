# ofxGgmlMusicExample

Focused companion example for `ofxGgmlMusicGenerator` and the optional AceStep bridge.

## What it demonstrates

- local-first text prompt preparation for music generation
- ABC notation sketch validation and saving without a model
- optional text-model prompt/ABC generation after setting `textModelPath`
- optional AceStep rendered audio through an external server
- the shared AceStep GGUF model directory: `models/acestep/gguf`

## Requirements

- `ofxGgml`
- optional local text GGUF model and llama.cpp completion executable for AI prompt/ABC generation
- optional AceStep-compatible server for rendered audio

## Run

Open or regenerate the project with the openFrameworks Project Generator. The app starts in preview mode without requiring models.

Keys:

- `P`: prepare and display a music prompt locally
- `A`: save the bundled ABC sketch
- `G`: generate prompt and ABC with `textModelPath`
- `H`: check the AceStep server health
- `R`: render audio through AceStep if a server is running

Put AceStep GGUF model assets under `models/acestep/gguf` or configure your external AceStep server to use another model directory.
