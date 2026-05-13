# ofxGgml Ecosystem Standards

These standards define the shared expectations for the ofxGgml addon family.

## Repository contract

Every addon should provide:

- `README.md`
- `addon_config.mk`
- `src/`
- `examples/`
- `scripts/`
- `docs/`
- `.github/copilot-instructions.md`
- `.github/pull_request_template.md`
- `.github/workflows/addon-hygiene.yml`
- `.github/workflows/release-check.yml`
- `AGENTS.md`
- `.codex/skills/openframeworks-addon/SKILL.md`
- `CHANGELOG.md`

## Addon boundaries

`ofxGgmlCore` owns backend-neutral primitives only.

Companion addons own domain workflows:

- `ofxGgmlLlama`: text, chat, embeddings, llama.cpp server/CLI
- `ofxGgmlAudio`: Whisper, transcription, voice/audio workflows
- `ofxGgmlSam`: segmentation
- `ofxGgmlDiffusion`: image generation and diffusion workflows
- `ofxGgmlVision`: CLIP, image embeddings, captions, image understanding
- `ofxGgmlRag`: retrieval, citations, local search
- `ofxGgmlAgents`: tool-using local agents and planning loops
- `ofxGgmlVideo`: video understanding and frame/temporal workflows
- `ofxGgmlMusic`: music analysis and generation

## Artifact policy

Do not commit:

- models
- generated builds
- binaries
- downloaded upstream source caches
- local IDE folders
- generated openFrameworks project files unless explicitly required

## Script policy

Prefer paired scripts for Windows and macOS/Linux:

- first-run
- doctor
- validate-local
- build-example
- run-example
- release-candidate

If parity is not possible, document the platform-specific limitation.

## Documentation policy

Update documentation when changing:

- setup
- public API
- examples
- scripts
- backend behavior
- model path assumptions
- addon boundaries

## Agent policy

AI agents should:

1. inspect existing conventions before editing
2. keep diffs small
3. preserve addon boundaries
4. update docs and scripts with code changes
5. report validation honestly
6. avoid committing artifacts
