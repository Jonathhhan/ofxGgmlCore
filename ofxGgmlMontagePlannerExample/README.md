# ofxGgmlMontagePlannerExample

Focused companion example extracted from the removed `ofxGgmlGuiExample` Montage workflow.

## What it demonstrates

- `ofxGgmlMontagePlanner` scoring and clip selection
- subtitle-track generation
- SRT and EDL export helpers
- an editor-facing handoff that avoids embedding post-production logic in the main GUI example

## Requirements

- `ofxGgml`
- optional speech-to-text input if you want to build segments from transcripts
- optional NLE or VLC preview tooling outside this example

## Run

The app builds a montage plan from sample transcript segments at startup. Press `B` to rebuild and `S` to save `bin/data/generated/montage/montage.srt` and `montage.edl`.
