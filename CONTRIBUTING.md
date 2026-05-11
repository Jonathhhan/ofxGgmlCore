# Contributing

`ofxGgml` is the small core addon. Before adding a feature, first decide whether
it belongs in core or in a companion addon.

## Start Here

Read these first:

- `docs/README.md` for the documentation map
- `docs/CORE_CONTRACT.md` for the public surface and non-goals
- `docs/COMPANIONS.md` for the core-versus-companion split rule
- `docs/ROADMAP.md` for the current checkpoint

## Change Rules

- Keep core changes small, backend-neutral, and testable.
- Prefer openFrameworks-style naming and examples.
- Do not add model downloads or large generated binaries.
- Do not commit generated ggml, llama.cpp, SAM3, model, or project output files.
- Put domain workflows in companion addons such as `ofxGgmlSam`,
  `ofxGgmlMusic`, or `ofxGgmlSpeech`.
- Update `docs/RELEASE_NOTES.md` when behavior, commands, public API, or
  user-facing docs change.

## Validation

Run the local validation before pushing:

```powershell
scripts\validate-local.bat
```

On macOS/Linux:

```sh
./scripts/validate-local.sh
```

When you change a specific example, also build or run that example directly.
Use the `-DryRun` variants when checking launch resolution without opening a
window.

## Public API

Public API changes should include focused tests and documentation updates. If a
change broadens the addon into a workflow, move it to a companion addon instead
of expanding core.
