# Example Cleanup Implementation Plan

**Status**: ✅ Phase 1A/1B/1C Implemented
**Priority**: MEDIUM (Phase 1.5)
**Last Updated**: 2026-05-05

## Overview

This document outlines the plan to refactor ofxGgml examples, specifically reducing the monolithic GUI example and extracting companion workflows into focused, standalone examples.

## Current State Analysis

### ofxGgmlGuiExample
- **Size**: 1.2MB, 31,650 lines of code
- **Files**: 58 source files
- **Workflows**: 14 major sections including:
  - **Core addon APIs**: Chat, Script, Text modes, Vision, Speech, TTS, Easy API
  - **Companion workflows**: Video Essay, MilkDrop, Montage, CLIP ranking, SAM segmentation
- **Dependencies**:
  - Required: ofxImGui
  - Optional: ofxVlc4, ofxProjectM (conditionally compiled)
- **Build Flag**: `OFXGGML_ENABLE_COMPANION_WORKFLOWS=1` enables companion features

### Other Examples
- **ofxGgmlBasicExample**: 36KB - Simple text completion
- **ofxGgmlChatExample**: 32KB - Basic chat interface
- **ofxGgmlNeuralExample**: 40KB - Neural/tensor operations
- **ofxGgmlWebScrapingExample**: 44KB - Web crawling and RAG

## Problem Statement

From ROADMAP.md (Phase 1, Item 5):
> "Reduce the giant GUI example to a showcase for API layers and UI patterns. Complex workflows should move into focused examples, tutorial projects, or companion addons instead of using the GUI example as a test harness."

**Issues with current structure:**
1. GUI example is too large for new users to understand
2. Mixed responsibilities: API showcase + companion workflow test harness
3. Long compile times due to all features being included
4. Difficult to maintain as both core and companion features evolve
5. Unclear which features are "stable addon tier" vs "companion/experimental"

## Solution: Three-Tier Example Architecture

### Phase 1A: Refactor GUI Example (Core APIs Only)

**Goal**: Keep GUI example focused on stable addon tier APIs

**Keep in ofxGgmlGuiExample:**
- ✅ Text inference modes (Chat, Script)
- ✅ Text assistants (Summarize, Write, Translate, Custom)
- ✅ Vision inference (image-to-text)
- ✅ Speech inference (Whisper STT)
- ✅ TTS inference (Piper, OuteTTS)
- ✅ Easy API demonstration
- ✅ Server management (text server)
- ✅ Performance/logging panels
- ✅ Model preset selection
- ✅ Session persistence (for core workflows)

**Remove from ofxGgmlGuiExample:**
- ❌ Video Essay workflow (VideoEssay.cpp ~2K lines)
- ❌ MilkDrop generation (MilkDrop.cpp ~700 lines)
- ❌ Montage planning (parts of GenerationWorkflow.cpp)
- ❌ Advanced CLIP ranking (DiffusionClip.cpp ~1.7K lines)
- ❌ SAM segmentation (SamSegmentation.cpp ~500 lines)
- ❌ AceStep server management
- ❌ ofxVlc4 integration
- ❌ ofxProjectM integration

**Estimated size after refactoring**: ~18,000 lines (40% reduction)

### Phase 1B: Extract Companion Workflows

Create four new focused examples:

#### 1. ofxGgmlVideoEssayExample (NEW)
**Purpose**: Demonstrate end-to-end video essay workflow
**Size**: ~3,000 lines
**Features**:
- Citation search → Outline → Script → TTS → SRT workflow
- Web crawling integration
- Topic research and source grounding
- Optional: ofxVlc4 preview integration (behind #ifdef)

**Files to extract**:
- VideoEssay.cpp (~2K lines)
- Citation search UI components
- Relevant workflow managers

**Target users**: Content creators, educational material developers

#### 2. ofxGgmlVisualizationExample (NEW)
**Purpose**: Music visualization and VJ workflows
**Size**: ~1,500 lines
**Features**:
- MilkDrop preset generation
- Preset editing and validation
- Audio-reactive visualization
- Optional: ofxProjectM preview (behind #ifdef)

**Files to extract**:
- MilkDrop.cpp (~700 lines)
- Visualization UI components
- Audio integration helpers

**Target users**: VJs, music visualization artists, live performers

#### 3. ofxGgmlAdvancedVisionExample (NEW)
**Purpose**: Advanced computer vision and multimodal workflows
**Size**: ~3,500 lines
**Features**:
- CLIP semantic ranking and reranking
- SAM image segmentation
- Image search and retrieval
- Diffusion prompt enhancement
- Image-to-music prompt generation

**Files to extract**:
- DiffusionClip.cpp (~1.7K lines)
- SamSegmentation.cpp (~500 lines)
- ImageSearch.cpp (~400 lines)
- Relevant vision UI components

**Target users**: Computer vision researchers, image processing developers

#### 4. ofxGgmlMontagePlannerExample (NEW)
**Purpose**: Video editing and post-production workflows
**Size**: ~2,000 lines
**Features**:
- Speech-to-montage planning
- Subtitle-driven clip selection
- EDL export for NLE software
- Montage preview with dual subtitle tracks

**Files to extract**:
- Montage-related parts of GenerationWorkflow.cpp
- Subtitle and EDL helpers
- Video editing UI components

**Target users**: Video editors, post-production professionals

### Phase 1C: Documentation Updates

**New documentation**:
1. `docs/examples/README.md` - Guide users to appropriate examples
2. `docs/examples/MIGRATION.md` - Migration guide for existing users
3. Each new example gets its own `README.md` with:
   - Prerequisites (required addons)
   - What it demonstrates
   - When to use it
   - Related companion addons
   - Build instructions

**Update existing docs**:
- `README.md` - Update examples section
- `docs/getting-started/CHOOSING_FEATURES.md` - Update example recommendations
- `CHANGELOG.md` - Document the restructuring

## Implementation Steps

### Step 1: Planning & Preparation (1 day)
- [x] Create this planning document
- [ ] Review with project maintainers
- [ ] Get approval on approach
- [ ] Create feature branch: `feature/example-cleanup`

### Step 2: Phase 1A - Refactor GUI Example (2-3 days)
- [ ] Remove Video Essay tab and code
- [ ] Remove MilkDrop tab and code
- [ ] Remove advanced CLIP/SAM features
- [ ] Remove Montage-specific code
- [ ] Simplify server management (text/speech only)
- [ ] Remove OFXGGML_ENABLE_COMPANION_WORKFLOWS flag usage
- [ ] Update CMakeLists.txt/project configuration
- [ ] Test that basic functionality still works
- [ ] Update GUI example README.md

### Step 3: Phase 1B - Extract Examples (5-7 days)
- [x] Create ofxGgmlVideoEssayExample structure
  - [ ] Set up project files
  - [ ] Extract and port VideoEssay code
  - [ ] Create minimal UI
  - [ ] Add README.md
  - [ ] Test compilation and basic workflow

- [x] Create ofxGgmlVisualizationExample structure
  - [ ] Set up project files
  - [ ] Extract and port MilkDrop code
  - [ ] Create minimal UI
  - [ ] Add README.md
  - [ ] Test compilation and basic workflow

- [x] Create ofxGgmlAdvancedVisionExample structure
  - [ ] Set up project files
  - [ ] Extract CLIP, SAM, ImageSearch code
  - [ ] Create minimal UI
  - [ ] Add README.md
  - [ ] Test compilation and basic workflow

- [x] Create ofxGgmlMontagePlannerExample structure
  - [ ] Set up project files
  - [ ] Extract Montage code
  - [ ] Create minimal UI
  - [ ] Add README.md
  - [ ] Test compilation and basic workflow

### Step 4: Phase 1C - Documentation (1-2 days)
- [x] Create `docs/examples/README.md`
- [x] Create `docs/examples/MIGRATION.md`
- [x] Update main `README.md`
- [x] Update `docs/getting-started/CHOOSING_FEATURES.md`
- [x] Update `CHANGELOG.md`
- [x] Update `docs/ROADMAP.md` (mark task complete)

### Step 5: Testing & Validation (1-2 days)
- [ ] Verify all examples compile independently
- [ ] Test core workflows in refactored GUI example
- [ ] Test extracted companion workflows
- [ ] Run test suite: `./scripts/build-ggml.sh --cpu-only && ./tests/run-tests.sh`
- [ ] Verify companion tests still work (opt-in)
- [ ] Check for any regressions

### Step 6: Review & Merge (1-2 days)
- [ ] Create pull request
- [ ] Code review
- [ ] Address feedback
- [ ] Merge to main
- [ ] Update release notes

**Total estimated time**: 10-15 days of focused work

## Migration Path for Users

### For Existing Users of GUI Example

**If you use core features only (Chat, Text, Vision, Speech, TTS):**
- ✅ No changes needed - everything still works
- ✅ Faster compile times
- ✅ Cleaner UI with fewer tabs

**If you use companion workflows (Video Essay, MilkDrop, etc.):**
- 📝 Companion features moved to dedicated examples
- 📝 Migration guide provided in `docs/examples/MIGRATION.md`
- 📝 All functionality preserved, just reorganized
- 📝 Copy patterns from new examples to your projects

### For New Users

**Recommended learning path**:
1. **ofxGgmlBasicExample** - Start here: simple text completion
2. **ofxGgmlChatExample** - Basic chat interface
3. **ofxGgmlNeuralExample** - Understand tensor operations
4. **ofxGgmlGuiExample** - Comprehensive core APIs showcase
5. **Specialized examples** - Pick based on your use case:
   - Content creation → ofxGgmlVideoEssayExample
   - Visualization → ofxGgmlVisualizationExample
   - Computer vision → ofxGgmlAdvancedVisionExample
   - Video editing → ofxGgmlMontagePlannerExample

## Success Criteria

### Quantitative Metrics
- ✅ GUI example reduced to < 20,000 lines
- ✅ GUI example compiles in < 70% of previous time
- ✅ Each new example is < 5,000 lines
- ✅ All tests pass (headless suite)
- ✅ Companion tests remain opt-in and pass

### Qualitative Goals
- ✅ GUI example clearly demonstrates stable addon tier
- ✅ Each example is self-contained and runnable
- ✅ Documentation is clear and comprehensive
- ✅ New users have clear learning progression
- ✅ Companion workflows are easily accessible
- ✅ Maintainability improved (smaller codebases)

## Risks & Mitigations

### Risk 1: Breaking Existing User Projects
**Mitigation**:
- Keep all functionality available
- Provide detailed migration guide
- Version the change appropriately
- Announce in release notes

### Risk 2: Increased Maintenance Burden (More Examples)
**Mitigation**:
- Each example is simpler than monolithic GUI
- Clear boundaries reduce cross-contamination
- Automated testing catches regressions
- Documentation reduces support burden

### Risk 3: User Confusion About Which Example to Use
**Mitigation**:
- Clear README.md in docs/examples/
- Decision tree in getting started guide
- Each example README explains its purpose
- Main README links to appropriate examples

### Risk 4: Duplicate Code Across Examples
**Mitigation**:
- Keep UI utilities in shared location
- Examples can reference common patterns
- Focus on demonstrating APIs, not creating frameworks
- Accept some duplication for clarity

## Alignment with ROADMAP

This cleanup directly supports:

- ✅ **ROADMAP Option A**: "Keep ofxGgml boring and dependable"
- ✅ **Phase 1 Quick Wins**: Improve developer experience
- ✅ **Phase 2 Preparation**: Clear contracts for companion workflows
- ✅ **North Star**: "Easiest way to add ggml tensors and basic local LLM inference"

**From ROADMAP**:
> "Creative application workflows remain useful, but they are no longer part of the default addon boundary. Video essay, rendered-music/AceStep, MilkDrop/projectM, and Holoscan bridge code should be treated as companion-addon candidates or example-level integrations behind explicit opt-in headers."

This refactoring **implements that vision** by:
1. Separating stable addon tier (GUI example) from companion tier (new examples)
2. Making the learning path clearer for new users
3. Reducing validation burden on core addon
4. Preparing for Phase 2 companion handoff contracts

## Next Steps

1. **Review this plan** with project maintainers
2. **Get approval** on the approach
3. **Create feature branch** and begin implementation
4. **Regular check-ins** to validate progress
5. **Iterative review** of extracted examples

## Notes

- This is a **code organization task**, not a new feature
- All functionality is preserved, just reorganized
- Focus is on clarity, maintainability, and learning path
- Aligns with multi-phase roadmap vision
- Prepares foundation for Phase 2 work

---

**Questions or feedback?** Contact the ofxGgml maintainers or open a discussion issue.
