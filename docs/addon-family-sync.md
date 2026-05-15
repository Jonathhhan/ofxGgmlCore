# Addon Family Sync Checklist

Use this checklist when creating or upgrading companion addons.

## Required repository files

- [ ] README.md
- [ ] addon_config.mk
- [ ] CHANGELOG.md
- [ ] AGENTS.md
- [ ] .github/copilot-instructions.md
- [ ] .github/pull_request_template.md
- [ ] .github/workflows/addon-hygiene.yml
- [ ] .github/workflows/release-check.yml
- [ ] .codex/skills/openframeworks-addon/SKILL.md

## Required folders

- [ ] src/
- [ ] examples/
- [ ] scripts/
- [ ] docs/

## Script parity

- [ ] first-run scripts
- [ ] doctor scripts
- [ ] validate-local scripts
- [ ] build-example scripts
- [ ] run-example scripts
- [ ] release-candidate scripts

## Artifact hygiene

Confirm the repo does not commit:

- [ ] model files
- [ ] generated binaries
- [ ] build folders
- [ ] downloaded upstream caches
- [ ] IDE-generated folders

## Documentation

- [ ] setup instructions updated
- [ ] backend requirements documented
- [ ] example usage documented
- [ ] model path expectations documented
- [ ] addon boundaries documented

## Validation

Recommended minimum checks:

```txt
./scripts/doctor.sh
./scripts/validate-local.sh
./scripts/release-candidate.sh
```

Windows equivalents should exist where practical. For companion addons, use the
addon-owned build/run-example scripts named by that lane; `build-simple-example`
is Core's compatibility wrapper for `ofxGgmlCoreExample`, not a companion-addon
template requirement.
