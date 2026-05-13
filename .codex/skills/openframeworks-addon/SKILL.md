# openFrameworks Addon Skill

Use this skill when working on the ofxGgml addon family.

## Addon layout

Each addon should keep the normal openFrameworks addon shape:

```txt
addon_config.mk
README.md
src/
examples/
scripts/
docs/
```

Do not commit:

- model files
- generated build folders
- downloaded upstream source caches
- binaries
- `.vs`, `bin/data/models`, `obj`, `build`, or temporary project files

## Core vs companion addons

`ofxGgmlCore` owns only shared, backend-neutral primitives:

- ggml setup
- runtime discovery
- tensor/graph helpers
- request/result base types
- small smoke-test examples
- doctor/validation scripts

Companion addons own model-specific workflows.

When a request crosses this boundary, explain which companion addon should own the change.

## C++ rules

- Prefer C++17.
- Keep headers lightweight.
- Avoid hidden global state.
- Make lifecycle explicit.
- Prefer small structs for request/result objects.
- Avoid blocking the OF draw/update loop with long inference work.

## openFrameworks conventions

- Examples should be runnable through projectGenerator.
- Keep examples minimal and visual.
- Use `bin/data` for small config/demo assets only.
- Never require large models to be committed.
- Document required model paths clearly.
- Keep addon dependencies explicit in `addons.make`.

## addon_config.mk

When adding or moving source files:

- update `ADDON_SOURCES`
- update `ADDON_INCLUDES`
- preserve platform sections
- avoid hardcoded absolute paths
- keep backend libraries grouped between marker comments

## Scripts

Maintain parity between shell and Windows scripts where practical.

Typical workflows:

- first-run
- doctor
- validate-local
- build-example
- run-example
- release-candidate

## Validation checklist

Before finishing a change, check the smallest relevant subset:

```sh
./scripts/doctor.sh
./scripts/validate-local.sh
./scripts/build-simple-example.sh
./scripts/run-simple-example.sh -Build
```

If checks cannot be run, explain why.

## Codex behavior

For complex tasks:

1. Inspect existing files first.
2. Plan before editing.
3. Keep changes small.
4. Preserve Core/companion boundaries.
5. Update docs/examples/scripts with code.
6. Summarize validation honestly.
