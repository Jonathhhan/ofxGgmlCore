---
name: openframeworks-addon
description: Use when working on openFrameworks addons, including addon_config.mk, src headers, examples, smoke builds, Visual Studio project generation, and addon documentation.
---

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

Use `openframeworks/ofxAddonTemplate` as the structural baseline when creating
or repairing addons:

- Addon names start with `ofx` and use camel-case capitalization.
- Keep root metadata and docs intentional: `README.md`, `license.md`,
  `CONTRIBUTING.md`, `addon_config.mk`, `src`, `libs`, `docs`, `tests`,
  `scripts`, and `example_*` folders.
- Example folder names must contain `example`; keep examples
  projectGenerator-friendly and list required addons one per line in
  `addons.make`.
- Put small example assets under the example `bin/data` folder.
- Vendor libraries live under `libs/<lib>/include` or `includes`,
  `libs/<lib>/src`, and `libs/<lib>/lib/<platform>`.
- Preserve openFrameworks platform library folder names such as `vs`, `osx`,
  `linux`, `linux64`, `ios`, and `android/armeabi*`.
- Use `.gitignore` and artifact hygiene for generated files; `.gitkeep` is only
  for preserving intentionally empty folders.
- Remove template author/deploy instructions from published addons, and make the
  final `README.md` addon-specific.

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

## openFrameworks code style

Follow the official openFrameworks code-style wiki when editing addon C++:

- Prefer the existing `.clang-format` style: tabs for indentation, braces on the
  same line, pointer/reference spacing like `char * value` and
  `const std::string & name`, and no manual column alignment.
- Declare each variable on its own line.
- Use lower-camel-case for variables and functions; use clear names and avoid
  abbreviations except for very local counters or obvious temporaries.
- Keep lines under roughly 100 characters where practical.
- Prefer clear code over clever code.
- Use comments for "why", not redundant "what"; use `// TODO:` for future work.
- Avoid multi-line block comments in source files.
- Use `ofLogNotice`, `ofLogWarning`, `ofLogError`, or module-scoped
  `ofLog(...)`; do not use `printf`, `cout`, or raw stdout in OF runtime code.
- Include the calling module/function in warnings and errors, for example
  `ofLogWarning("ofxAddon::setup()") << "message";`.
- Avoid ternary operators when a simple `if` is clearer.
- Avoid `while` loops when a `for` loop or range-based `for` is clearer.
- Use simple incrementing `for` loops for simple index cases, range-based `for`
  for containers, and iterators only when needed.
- Prefer `std::vector` over C arrays unless there is a strong reason.
- Use const arguments and const methods for new code where practical, while not
  forcing users into awkward const-only APIs.
- Initialize members with sensible defaults; pointers start as `nullptr` in new
  C++ code.
- Do not use `assert` in addon/runtime code.
- Avoid throwing exceptions into user code; catch library exceptions and log a
  warning/error when needed.
- Prefer re-applicable `setup()` or `set()` methods for objects; use `Settings`
  structs for complex setup arguments.
- Order header methods from least technical to most technical: constructor,
  setup/initialization, core functionality, operators, then member variables.
- Use `ofx` prefixes for addon classes and APIs; do not globally
  `using namespace std`.
- Keep member variables private except for tiny data-passing structs; use
  getters/setters when public access is needed.
- Use enums for option sets instead of untyped `int` values or preprocessor
  constants.

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

Use template-style `addon_config.mk` rules:

- Fill `meta:` fields such as `ADDON_NAME`, `ADDON_DESCRIPTION`,
  `ADDON_AUTHOR`, `ADDON_TAGS`, and `ADDON_URL`.
- Use `=` only when replacing inferred values; use `+=` when appending.
- Use `%` wildcards for exclusions.
- Keep `common:` settings and platform sections explicit when automatic
  filesystem discovery is not enough.
- Use platform-specific fields when needed, such as `ADDON_DLLS_TO_COPY` for
  Visual Studio, `ADDON_FRAMEWORKS` for macOS/iOS, and
  `ADDON_PKG_CONFIG_LIBRARIES` for linux64.
- Validate structural changes by generating or building an example that uses the
  addon.

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
