#!/usr/bin/env python3

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
METADATA = ROOT / "ofxggml-addon.json"
OUTPUT = ROOT / "docs" / "backend-capability-report.md"

BACKEND_LIBRARY_CANDIDATES = {
    "cpu": ["ggml-cpu.lib", "libggml-cpu.a", "ggml-cpu.dll"],
    "cuda": ["ggml-cuda.lib", "libggml-cuda.a", "ggml-cuda.dll"],
    "metal": ["ggml-metal.lib", "libggml-metal.a", "ggml-metal.dylib"],
    "vulkan": ["ggml-vulkan.lib", "libggml-vulkan.a", "ggml-vulkan.dll"],
    "opencl": ["ggml-opencl.lib", "libggml-opencl.a", "ggml-opencl.dll"],
}


def has_any(root: Path, names: list[str]) -> bool:
    return any((root / name).exists() for name in names)


def backend_state(backend: str) -> dict[str, str]:
    lib_dir = ROOT / "libs" / "ggml" / "lib"
    include_dir = ROOT / "libs" / "ggml" / "include"
    libraries_present = has_any(lib_dir, BACKEND_LIBRARY_CANDIDATES.get(backend, []))
    headers_present = include_dir.exists() and any(include_dir.glob("ggml*.h"))

    if not headers_present:
        return {
            "runtime": "missing headers",
            "inference": "not checked",
            "status": "run `scripts\\setup-ggml.bat`",
        }

    if libraries_present:
        return {
            "runtime": "local library present",
            "inference": "not checked",
            "status": "ready for runtime init smoke",
        }

    return {
        "runtime": "not installed locally",
        "inference": "not checked",
        "status": "optional backend absent",
    }


def main():
    metadata = json.loads(METADATA.read_text(encoding="utf-8"))
    declared_backends = metadata.get("backends", [])

    lines = [
        "# Backend Capability Report",
        "",
        "Generated from Core metadata and local ggml runtime files.",
        "",
        "| Backend | Declared support | Local runtime evidence | Inference smoke | Status |",
        "| --- | --- | --- | --- | --- |",
    ]

    for backend in declared_backends:
        state = backend_state(backend)
        lines.append(
            f"| `{backend}` | yes | {state['runtime']} | {state['inference']} | {state['status']} |"
        )

    lines.extend([
        "",
        "## Interpretation",
        "",
        "- This is phase-1 backend discovery evidence, not a release-grade inference certificate.",
        "- `local library present` means Core can see a built ggml backend artifact on this machine.",
        "- Optional backend absence is reported without failing unrelated validation.",
        "- Release gating still needs phase-2 runtime initialization and phase-3 inference smoke evidence.",
    ])

    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
