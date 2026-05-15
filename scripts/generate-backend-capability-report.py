#!/usr/bin/env python3

import argparse
import json
import os
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


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def load_runtime_smoke_results(report_path: Path | None) -> dict[str, dict[str, str]]:
    if not report_path or not report_path.exists():
        return {}
    try:
        payload = json.loads(report_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return {}

    results = {}
    for record in payload.get("results", []):
        backend = record.get("backend", "")
        if not backend:
            continue
        output = "\n".join(record.get("output", []))
        if record.get("passed"):
            inference = "passed" if "Lightweight inference smoke test passed" in output else "runtime initialized"
            results[backend] = {
                "runtime": "runtime smoke passed",
                "inference": inference,
                "status": "validated locally",
            }
        else:
            results[backend] = {
                "runtime": "runtime smoke failed",
                "inference": "failed",
                "status": f"see `{display_path(report_path)}`",
            }
    return results


def backend_state(backend: str, runtime_results: dict[str, dict[str, str]]) -> dict[str, str]:
    if backend in runtime_results:
        return runtime_results[backend]

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
    parser = argparse.ArgumentParser(description="Generate the local backend capability report.")
    parser.add_argument(
        "--runtime-smoke-report",
        default=os.environ.get("OFXGGML_RUNTIME_SMOKE_REPORT", ""),
        help="Optional runtime smoke JSON report to include as local validation evidence.",
    )
    args = parser.parse_args()

    metadata = json.loads(METADATA.read_text(encoding="utf-8"))
    declared_backends = metadata.get("backends", [])
    runtime_report = Path(args.runtime_smoke_report).resolve() if args.runtime_smoke_report else None
    runtime_results = load_runtime_smoke_results(runtime_report)

    lines = [
        "# Backend Capability Report",
        "",
        "Generated from Core metadata and local ggml runtime files.",
        "",
        "| Backend | Declared support | Local runtime evidence | Inference smoke | Status |",
        "| --- | --- | --- | --- | --- |",
    ]

    for backend in declared_backends:
        state = backend_state(backend, runtime_results)
        lines.append(
            f"| `{backend}` | yes | {state['runtime']} | {state['inference']} | {state['status']} |"
        )

    lines.extend([
        "",
        "## Interpretation",
        "",
        "- This is phase-1 backend discovery evidence, not a release-grade inference certificate.",
        "- `local library present` means Core can see a built ggml backend artifact on this machine.",
        "- `runtime smoke passed` means `scripts\\build-runtime-smoke.ps1` initialized the backend and ran the lightweight graph smoke locally.",
        "- Optional backend absence is reported without failing unrelated validation.",
        "- Release gating still needs phase-2 runtime initialization and phase-3 inference smoke evidence.",
    ])

    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
