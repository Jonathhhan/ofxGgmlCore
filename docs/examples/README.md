# ofxGgml Examples

Use the smallest example that matches the layer you want to learn or ship.

| Example | Layer | Use when |
|---------|-------|----------|
| `ofxGgmlBasicExample` | Core | You want backend setup, tensors, and graph execution. |
| `ofxGgmlChatExample` | Basic | You want a small local chat UI. |
| `ofxGgmlNeuralExample` | Core | You want lower-level neural/tensor operations. |
| `ofxGgmlWebScrapingExample` | Workflows | You want crawler-backed source ingestion and RAG-style workflows. |
| `ofxGgmlGuiExample` | Stable addon showcase | You want one UI that demonstrates core text, assistant, speech, TTS, vision, and Easy APIs. |
| `ofxGgmlVideoEssayExample` | Companion workflow | You want citation-grounded video essay planning and script/SRT handoffs. |
| `ofxGgmlVisualizationExample` | Companion workflow | You want MilkDrop preset generation, repair, validation, and saving. |
| `ofxGgmlAdvancedVisionExample` | Companion workflow | You want CLIP ranking, image search, SAM-style segmentation, and diffusion bridge patterns. |
| `ofxGgmlMontagePlannerExample` | Companion workflow | You want transcript/subtitle-driven clip selection plus SRT/EDL exports. |

## Recommended path

1. Start with `ofxGgmlChatExample` or `ofxGgmlBasicExample`.
2. Use `ofxGgmlGuiExample` to see stable addon-tier APIs together.
3. Move to a focused companion example only when your project needs that workflow.
4. Copy the companion example pattern into your own app rather than adding the old GUI workflow back to `ofxGgmlGuiExample`.

## Companion boundaries

The four companion examples were split out of removed GUI code so the main GUI stays a stable API showcase. They intentionally keep optional runtime integrations behind explicit setup:

- video preview/rendering belongs in an app or companion addon such as an `ofxVlc4`-enabled project
- MilkDrop live preview belongs in an app that opts into `ofxProjectM`
- diffusion generation belongs behind an `ofxStableDiffusion` bridge
- SAM segmentation belongs behind a `sam.cpp` bridge

This keeps `ofxGgml` focused on handoff contracts, validation, and local-first inference helpers.
