# ofxGgml Strategic Roadmap

This document tracks the next major direction for ofxGgml as it evolves from a collection of local AI helpers into a **local creative AI operating system for openFrameworks**.

**Last Updated**: 2026-05-03  
**Current Version**: 1.0.4

---

## North Star

ofxGgml should be the easiest way to build **local-first, source-grounded, reproducible creative AI applications** in openFrameworks.

That means prioritizing:

- **Local orchestration** over thin model wrappers
- **Composable workflows** over isolated helper classes
- **Inspectable outputs** over black-box automation
- **Approval-first assistants** over unsafe autonomous edits
- **Creative-media workflows** over generic AI demos

---

## Guiding Product Principles

1. **Local by default**  
   Core workflows should run with local models, local tools, and local files whenever possible.

2. **Verifiable by design**  
   Research, generation, editing, and automation features should expose provenance, warnings, confidence, and reproducibility metadata.

3. **Composable across modalities**  
   Text, speech, vision, video, code, and web ingestion should connect through stable workflow contracts instead of bespoke glue.

4. **Useful for artists and developers**  
   APIs should work for creative coding apps, IDE-like assistants, and media-production tools without forcing a single UX model.

5. **Reference examples, not monoliths**  
   The GUI example should demonstrate addon APIs, while feature logic continues moving into reusable addon modules.

---

## Delivery Phases

## Phase 1: Quick Wins (0-3 Months)

Focus: remove adoption friction and improve day-to-day usability.

### 1. Model Onboarding and Compatibility
**Priority**: HIGH  
**Status**: 📋 Planned

Build a first-class model onboarding flow that combines:

- direct model download helpers
- integrity verification and provenance checks
- compatibility hints for modality/backend requirements
- preset recommendations by task and hardware profile

**Outcome**: new users can go from zero setup to a working local model path with less manual documentation chasing.

### 2. Health and Runtime Observability
**Priority**: HIGH  
**Status**: 📋 Planned

Expand monitoring beyond point APIs into a unified health surface for:

- backend availability
- queue depth and request pressure
- CPU, RAM, and VRAM usage
- latency and throughput trends
- degraded-mode warnings and fallback hints

**Outcome**: the GUI example and host apps can expose operational status instead of only failure logs.

### 3. Semantic Cache
**Priority**: HIGH  
**Status**: 📋 Planned

Add semantic-result caching so repeated or closely related prompts can reuse prior work across chat, assistants, and workflow stages.

**Outcome**: faster iteration for creative prompting, review loops, and research-heavy tasks.

### 4. Hybrid Retrieval
**Priority**: HIGH  
**Status**: 📋 Planned

Upgrade retrieval workflows with hybrid keyword + embedding ranking and optional reranking.

**Outcome**: better grounding quality for citation search, RAG, and research-driven assistants.

### 5. Roadmap-Aligned Example Cleanup
**Priority**: MEDIUM  
**Status**: 📋 Planned

Continue extracting feature logic out of the giant GUI example and into addon APIs or focused helper modules.

**Outcome**: the example becomes easier to maintain and better demonstrates stable surfaces.

---

## Phase 2: Platform Composition (3-6 Months)

Focus: turn existing helpers into a reusable workflow system.

### 1. Workflow Graph Runtime
**Priority**: HIGH  
**Status**: 💡 Proposed

Introduce reusable workflow graphs so apps can connect stages like:

`crawl -> cite -> outline -> script -> TTS -> subtitles -> video plan`

Target capabilities:

- typed workflow nodes
- shared input/output contracts
- resumable execution
- inspectable intermediate outputs
- replay support for deterministic debugging

### 2. Shared Workflow Manifest
**Priority**: HIGH  
**Status**: 💡 Proposed

Standardize a manifest format that can carry:

- inputs and resolved assets
- prompts and settings
- citations and provenance
- intermediate artifacts
- warnings, confidence, and review notes
- downstream handoff metadata

**Outcome**: outputs from one workflow become reliable inputs for the next.

### 3. Project Memory Across Creative Runs
**Priority**: MEDIUM-HIGH  
**Status**: 💡 Proposed

Extend memory beyond code assistance into long-lived project context for:

- prompts and creative intent
- accepted references and citations
- style notes and continuity rules
- preferred tools and workflow settings

**Outcome**: long-form creative projects keep context across sessions.

### 4. Focused Example Applications
**Priority**: MEDIUM  
**Status**: 💡 Proposed

Ship more narrowly scoped examples for:

- research and citation workflows
- video essay generation
- speech + subtitle tooling
- coding assistant integration
- CLIP/image search and visual planning

**Outcome**: easier onboarding and less pressure on a single all-in-one example.

---

## Phase 3: Assistant Systems and Creative Copilots (6-9 Months)

Focus: move from single assistants to coordinated specialist systems.

### 1. Specialist Assistant Teams
**Priority**: HIGH  
**Status**: 💡 Proposed

Evolve assistants toward explicit roles such as:

- researcher
- planner
- critic
- editor
- renderer

The key constraint is to preserve approval-first execution and workspace safety while improving delegation and handoff quality.

### 2. Timeline-Aware Creative Copilots
**Priority**: HIGH  
**Status**: 💡 Proposed

Invest in assistant patterns tailored to media creation:

- video essay planning
- montage building
- music-video planning
- subtitle editing and revision
- generative visual pipelines

**Outcome**: ofxGgml becomes purpose-built for AI-native creative tools rather than generic chat wrappers.

### 3. Continuity, Consistency, and Asset Reuse
**Priority**: MEDIUM-HIGH  
**Status**: 💡 Proposed

Add system support for:

- scene continuity across long-form video planning
- style consistency across generated prompts and outputs
- reusable asset references and project-level constraints

**Outcome**: better long-form coherence for multi-stage creative work.

### 4. Trust and Evaluation Suites
**Priority**: MEDIUM-HIGH  
**Status**: 💡 Proposed

Build repeatable evaluation coverage for:

- citation quality
- workflow correctness
- latency and throughput
- multimodal coherence
- assistant safety and approval behavior

**Outcome**: “local and verifiable” becomes an enforceable product property, not just positioning.

---

## Phase 4: Ecosystem and Extensibility (9-12 Months)

Focus: let other developers build on the platform.

### 1. Plugin System
**Priority**: HIGH  
**Status**: 💡 Proposed

Create a plugin architecture for:

- custom inference backends
- workflow nodes
- modalities and renderers
- search/retrieval providers
- tool adapters and assistant capabilities

### 2. Third-Party Integration Surface
**Priority**: MEDIUM-HIGH  
**Status**: 💡 Proposed

Encourage integrations with:

- editors and IDE-like shells
- external renderers and media tools
- search providers and research pipelines
- hardware/media runtimes

### 3. Personalization and Adaptation
**Priority**: MEDIUM  
**Status**: 💡 Proposed

Explore higher-level personalization features such as:

- LoRA adapter support
- reusable project presets
- stylistic profiles for media generation

### 4. Collaborative and Real-Time Workflows
**Priority**: MEDIUM  
**Status**: 💡 Proposed

After core local flows are stable, evaluate real-time and collaborative creative pipelines that build on the manifest, memory, and plugin foundations.

---

## Cross-Cutting Workstreams

These themes should shape every phase rather than live in only one release.

### Trust and Provenance
- keep source trails, warnings, and confidence visible
- preserve reproducibility metadata in workflow artifacts
- prefer inspectable structured outputs for handoff-heavy systems

### Stable Addon APIs
- move logic out of example code and into reusable addon surfaces
- avoid locking roadmap features inside one GUI-specific implementation

### Performance and Responsiveness
- prioritize caching, batching, backpressure, and resumable execution
- expose runtime signals that let hosts adapt to local hardware constraints

### Documentation and Learnability
- align README, roadmap, and focused examples around the same product story
- explain not just isolated features, but how they combine into creative systems

---

## Suggested Priority Order

### First
- model onboarding
- health monitoring and runtime dashboards
- semantic cache
- hybrid retrieval

### Next
- workflow graph/runtime
- shared workflow manifests
- GUI modularization
- focused example apps

### Then
- specialist multi-agent orchestration
- plugin ecosystem
- project memory across sessions
- evaluation suites

### Finally
- advanced creative copilots
- personalization and LoRA-style adaptation
- collaborative and real-time creative pipelines

---

## What Success Looks Like

ofxGgml will have reached this roadmap’s goal when an openFrameworks developer can:

- install and validate the right local model stack quickly
- compose text, vision, speech, code, and video workflows through stable APIs
- inspect where outputs came from and why decisions were made
- build safe assistant-driven tools with approval gates and replayable execution
- reuse manifests, memory, and plugins across multiple creative applications

At that point, ofxGgml is no longer just a wrapper around model runtimes. It is the **local creative AI systems layer** for openFrameworks.
