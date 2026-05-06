# Migrating from GUI Companion Workflows

Phase 1A removed companion media workflows from `ofxGgmlGuiExample`. Phase 1B moves those patterns into focused examples so existing users can keep the functionality without using the main GUI as a test harness.

## What stayed in `ofxGgmlGuiExample`

- Chat, Script, Summarize, Write, Translate, and Custom text modes
- Vision, Speech, and TTS modes
- Easy API demonstrations
- text server management, model presets, status, logging, and performance panels

If you only used those APIs, no migration is required.

## What moved

| Old GUI area | New focused example | Primary APIs |
|--------------|---------------------|--------------|
| Video Essay / Long Video | `ofxGgmlVideoEssayExample` | `ofxGgmlVideoEssayWorkflow`, `ofxGgmlVideoPlanner`, citation search, SRT helpers |
| MilkDrop | `ofxGgmlVisualizationExample` | `ofxGgmlMilkDropGenerator` |
| Diffusion / CLIP / Image Search | `ofxGgmlAdvancedVisionExample` | `ofxGgmlDiffusionInference`, `ofxGgmlClipInference`, `ofxGgmlImageSearch` |
| SAM segmentation | `ofxGgmlSamExample` | `ofxGgmlSegmentationInference`, `ofxGgmlSamCppAdapters` |
| Montage planning | `ofxGgmlMontagePlannerExample` | `ofxGgmlMontagePlanner`, subtitle helpers, EDL export |

## Migration checklist

- Choose the focused example that matches the old GUI panel you depended on.
- Copy only the request-building, validation, export, and bridge setup patterns you need.
- Keep optional runtime addons explicit in your project rather than adding them to the default GUI example.
- Include `ofxGgmlCompanionWorkflows.h` for video essay, montage, MilkDrop, music, AceStep, or Holoscan companion surfaces.
- Include `ofxGgmlModalities.h` plus direct bridge headers for advanced vision, diffusion, CLIP, segmentation, and image search surfaces.
- Store generated media, manifests, subtitles, and EDLs under your app-owned `bin/data/generated/` or another explicit output directory.

## Notes for existing project files

The old GUI had conditional hooks for optional addons such as `ofxVlc4`, `ofxProjectM`, `ofxStableDiffusion`, and `sam.cpp`. The new examples do not add those addons by default. Add them only to the focused project that needs them and keep their setup behind compile-time or runtime checks.

## Why this changed

The GUI example had grown into both an API showcase and a companion workflow harness. Splitting the workflows makes onboarding easier, keeps compile times lower for stable addon APIs, and gives each companion workflow a clearer migration target.
