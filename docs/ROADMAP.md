# ofxGgml Strategic Roadmap

**Last Updated**: 2026-05-06  
**Current Version**: 1.0.4  
**Roadmap State**: ✅ Foundation roadmap complete; active work has moved to maintenance, polish, and companion-layer execution.

This document tracks the Option A direction for ofxGgml: keep the default addon boring, dependable, and focused on ggml tensors plus basic local LLM inference. Larger creative-application workflows should stay in companion addons or focused examples so every user does not inherit every experiment.

## North Star

ofxGgml should be the easiest way to add **ggml tensors and basic local LLM inference** to openFrameworks projects.

The core addon should provide predictable infrastructure:

- stable tensor, model, text, and optional modality APIs
- local-first model setup and runtime diagnostics
- inspectable inference, provenance, and handoff metadata
- focused examples that demonstrate addon layers without becoming monoliths
- companion-ready contracts for creative workflows outside the default addon boundary

## Status Summary

| Area | Status | Current result |
|------|--------|----------------|
| Phase 1: Quick Wins | ✅ Complete | Model onboarding, health monitoring, semantic cache, hybrid retrieval, and roadmap-aligned example cleanup are implemented. |
| Phase 2: Companion Handoff Contracts | ✅ Complete | Workflow manifests, stage contracts, companion project memory, and focused example catalogs are available. |
| Phase 3: Assistant Reliability and Companion Copilots | ✅ Complete at foundation level | Assistant-team, timeline-copilot, continuity/asset-ledger, and trust/evaluation schemas are available. |
| Phase 4: Ecosystem and Extensibility | ✅ Complete at foundation level | Plugin metadata, third-party integration surfaces, personalization profiles, and collaborative workflow schemas are available. |

The roadmap is complete at the shared-schema and addon-foundation level. Future work should build executable loaders, transports, orchestration, and UI polish on top of these contracts without expanding the default addon boundary.

## Completed Foundation

### Phase 1: Quick Wins

Focus: remove adoption friction and improve day-to-day usability.

- ✅ **Model Onboarding and Compatibility**
  - catalog-backed preset listing and task recommendations
  - download planning through `ofxGgmlEasy`
  - strict checksum support in `scripts/download-model.sh`
  - provenance fields for publisher, source type, and verification status
  - 6 of 7 catalog models currently carry verified SHA256 values

- ✅ **Health and Runtime Observability**
  - `ofxGgmlEasyHealthSnapshot`
  - `ofxGgmlEasyDiagnosticsReport` JSON export
  - `ofxGgml::getMemoryUsage()`
  - `ofxGgmlInference::getServerQueueStatus()`
  - cache, latency, throughput, and degraded-mode diagnostics

- ✅ **Semantic Cache**
  - `ofxGgmlSemanticCache`
  - configurable similarity, entry limits, and TTL
  - exact-match fast path before semantic matching
  - model/settings isolation and LRU expiration
  - cache stats for hit rates and memory usage

- ✅ **Hybrid Retrieval**
  - `ofxGgmlRAGPipeline`
  - keyword, semantic, and quality-weighted scoring
  - query variants, optional reranking, and retrieval cache reporting
  - chunk quality/depth tracking and top-K controls

- ✅ **Roadmap-Aligned Example Cleanup**
  - GUI example narrowed toward stable addon-tier APIs
  - removed companion workflow pressure from the default example
  - focused examples added for video essay, visualization, advanced vision, and montage planning
  - example chooser and migration guide added under `docs/examples/`

### Phase 2: Companion Handoff Contracts

Focus: define small, stable contracts that let companion projects compose workflows without turning ofxGgml into the workflow application.

- ✅ **Workflow Handoff Contracts**
  - `ofxGgmlWorkflowManifest`
  - typed stage input/output contracts
  - intermediate IDs, replay hints, warnings, review notes, and handoff metadata

- ✅ **Shared Workflow Manifest**
  - schema version `ofxGgml.workflow_manifest.v1`
  - `contracts`, `handoff`, `execution_steps`, and `replay` blocks
  - stable JSON keys covered by tests

- ✅ **Companion Project Memory**
  - `ofxGgmlCompanionProjectMemory`
  - creative intent, accepted prompts, references, style notes, continuity rules, preferred settings, manifest links, and review notes

- ✅ **Focused Example Applications**
  - `ofxGgmlFocusedExampleCatalog`
  - default tracks for research/citations, video essays, speech/subtitles, coding assistants, and CLIP/image planning

### Phase 3: Assistant Reliability and Companion Copilots

Focus: keep assistant surfaces safe and inspectable while letting companion projects explore coordinated creative systems.

- ✅ **Specialist Assistant Teams**
  - `ofxGgmlAssistantTeamSpec`
  - default researcher, planner, critic, editor, and renderer roles
  - approval-first handoffs and workspace rules

- ✅ **Timeline-Aware Companion Copilots**
  - `ofxGgmlTimelineCopilotPlan`
  - lanes, anchors, approval checkpoints, workspace rules, and manifest/memory handoffs

- ✅ **Continuity, Consistency, and Asset Reuse**
  - `ofxGgmlContinuityAssetLedger`
  - scene continuity rules, style constraints, reusable asset references, and review notes

- ✅ **Trust and Evaluation Suites**
  - `ofxGgmlTrustEvaluationSuite`
  - citation quality, workflow correctness, latency/throughput, multimodal coherence, assistant safety, evidence references, and approval rules

### Phase 4: Ecosystem and Extensibility

Focus: let developers build companion layers on top of the stable addon foundation.

- ✅ **Plugin System**
  - `ofxGgmlPluginRegistry`
  - plugin descriptors, capability declarations, ABI/schema versions, lifecycle notes, safety requirements, and compatibility rules

- ✅ **Third-Party Integration Surface**
  - `ofxGgmlIntegrationSurface`
  - editor shells, renderers/media tools, search providers, research pipelines, and hardware/media runtimes

- ✅ **Personalization and Adaptation**
  - `ofxGgmlPersonalizationProfileSet`
  - LoRA-style adapters, reusable project presets, style profiles, adaptation rules, safety requirements, and review notes

- ✅ **Collaborative and Real-Time Workflows**
  - `ofxGgmlCollaborativeWorkflowSpace`
  - local-first sessions, participants, realtime channels, approval checkpoints, sync rules, review notes, and manifest/project-memory handoffs

## Active Maintenance and Optimization Backlog

These are the next useful improvements now that the phased roadmap foundation is complete.

### 1. Keep the Core Boundary Small

- keep `ofxGgmlBasic.h`, `ofxGgml.h`, `ofxGgmlModalities.h`, `ofxGgmlWorkflows.h`, and `ofxGgmlCompanionWorkflows.h` boundaries explicit
- avoid adding companion-only orchestration to the default include path
- keep GUI/example additions focused on demonstrating addon APIs instead of becoming product workflows
- move reusable companion experiments behind opt-in headers or separate examples

### 2. Polish API Consistency

- add non-breaking `Result<T>` variants for public APIs that currently return only `bool` or ad-hoc result structs
- document raw pointer ownership/lifetime for backend accessors
- keep old APIs stable until a major-version migration path exists
- prefer additive wrappers and migration notes over breaking changes

### 3. Improve Runtime Performance Signals

- continue exposing cache, batching, backpressure, warmup, and queue metrics through inspectable structs
- profile semantic-cache and hybrid-retrieval memory growth under long sessions
- keep server-first inference paths observable enough for host apps to adapt to local hardware pressure
- prefer bounded buffers and explicit limits for long-running creative sessions

### 4. Tighten Model and Supply-Chain Hygiene

- keep model catalog provenance current
- verify any missing catalog checksum before promoting a preset as production-ready
- keep strict checksum mode documented for release and CI workflows
- preserve local-first setup paths without bundling model files

### 5. Maintain Documentation as Product Surface

- keep this roadmap concise and current
- keep archived implementation reports out of the active roadmap
- keep README, `docs/API_STABILITY.md`, and examples aligned with the same core-vs-companion boundary
- link to focused docs instead of duplicating long reports inside the roadmap

## Current Success Criteria

ofxGgml is on track when an openFrameworks developer can:

- install and validate the right local model stack quickly
- include only the addon layers their project needs
- use stable tensor, model, text, and optional modality APIs without inheriting unrelated experiments
- inspect where outputs came from and why decisions were made
- build assistant-driven tools with approval gates and replayable execution
- hand off manifests, memory, plugins, and evaluation metadata to companion applications without making the core addon own those apps

## Decision Rule for Future Roadmap Items

Before adding a new roadmap item, decide where it belongs:

| If the feature is... | Put it in... |
|----------------------|--------------|
| stable tensor/model/runtime infrastructure | core addon |
| broadly useful local inference helper | default addon tier after tests/docs |
| optional modality bridge | `ofxGgmlModalities.h` or focused example |
| workflow orchestration or creative product behavior | `ofxGgmlWorkflows.h`, companion header, focused example, or companion addon |
| experimental app-specific UI | example or companion project |
| third-party runtime integration | plugin/integration metadata first, executable adapter second |

This keeps the completed roadmap useful: the foundation can support ambitious creative AI systems, but the default addon remains boring, inspectable, and dependable.
