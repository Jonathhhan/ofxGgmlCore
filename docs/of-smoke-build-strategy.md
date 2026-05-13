# openFrameworks Smoke Build Strategy

## Goal

Evolve the ecosystem from structural CI validation toward real openFrameworks example compilation validation.

## Current state

The ecosystem currently provides:

- multi-platform smoke-build scaffolding
- metadata validation
- baseline compatibility enforcement
- live workflow observability scaffolding

Current smoke workflows do not yet compile examples.

## Planned smoke-build phases

### Phase 1

Structural validation only:

- repository structure
- examples directory presence
- workflow inheritance
- metadata validation

### Phase 2

Project generation validation:

- install openFrameworks
- run projectGenerator
- generate example projects
- verify generated project structure

### Phase 3

Compilation validation:

- compile minimal examples
- validate addon_config.mk integration
- validate include/source paths
- validate platform-specific project generation

### Phase 4

Runtime smoke tests:

- minimal inference startup
- backend initialization
- lightweight model loading
- CPU runtime verification
- optional CUDA/Metal/Vulkan verification

## Long-term direction

The ecosystem should eventually support:

- backend capability verification
- compatibility enforcement from real builds
- release gating from operational truth
- ecosystem-wide runtime health visibility
- autonomous release-train coordination
