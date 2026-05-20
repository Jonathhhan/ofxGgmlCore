# ofxGgml Coding Agent Work Queue

Generated from local ecosystem status. This queue is intended for Codex, GitHub Copilot, Hermes Agent, and similar coding assistants.

## Snapshot

| Metric | Count |
| --- | ---: |
| Managed repositories | 10 |
| Ready managed repositories | 7 |
| Workflow guides detected | 10 |
| Detected reference repositories | 9 |
| Proposed tasks | 3 |

## Queue

| Priority | Repository | Lane | Category | Task | Suggested files | Validation |
| --- | --- | --- | --- | --- | --- | --- |
| P1 | `ofxGgmlCore` | `backend-neutral runtime base` | hygiene | Review and either publish or isolate local dirty changes before starting new agent work. | `repository working tree` | `git status --short` |
| P1 | `ofxGgmlLlama` | `text, chat, embeddings` | hygiene | Review and either publish or isolate local dirty changes before starting new agent work. | `repository working tree` | `git status --short` |
| P1 | `ofxGgmlAgents` | `tool-using local agents` | hygiene | Review and either publish or isolate local dirty changes before starting new agent work. | `repository working tree` | `git status --short` |

## Auto-Detected Completed Planning Guides

| Repository | Guide |
| --- | --- |
| `ofxGgmlAgents` | `docs\AGENT_WORKFLOWS.md` |
| `ofxGgmlAudio` | `docs\AUDIO_WORKFLOWS.md` |
| `ofxGgmlCore` | `docs\ECOSYSTEM_AGENT.md` |
| `ofxGgmlLlama` | `docs\LLAMA_WORKFLOWS.md` |
| `ofxGgmlMusic` | `docs\MUSIC_WORKFLOWS.md` |
| `ofxGgmlRag` | `docs\RAG_WORKFLOWS.md` |
| `ofxGgmlSam` | `docs\SAM_WORKFLOWS.md` |
| `ofxGgmlVideo` | `docs\VIDEO_WORKFLOWS.md` |
| `ofxGgmlVision` | `docs\VISION_WORKFLOWS.md` |
| `ofxGgmlWorkflows` | `docs\workflow-adoption.md` |

## Guardrails

- Work on planning, instructions, workflow, validation, and documentation first.
- Do not edit addon runtime/source behavior unless the user explicitly asks for that repository and behavior.
- Keep classified reference repositories out of generated automation unless they are intentionally promoted.
- Prefer one small repository-scoped pull request over broad cross-repo edits.
- Run the suggested validation before pushing.
