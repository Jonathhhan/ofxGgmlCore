#!/usr/bin/env python3

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "backend-capability-report.md"

BACKENDS = ["cpu", "cuda", "metal", "vulkan", "opencl"]


def main():
    lines = [
        "# Backend Capability Report",
        "",
        "This report summarizes declared vs validated backend support.",
        "",
        "| Backend | Declared support | Runtime verification | Inference smoke | Status |",
        "| --- | --- | --- | --- | --- |",
    ]

    for backend in BACKENDS:
        declared = "expected"
        runtime = "planned"
        inference = "planned"

        if backend == "cpu":
            runtime = "implemented"
            inference = "implemented"

        lines.append(
            f"| `{backend}` | {declared} | {runtime} | {inference} | evolving |"
        )

    lines.extend([
        "",
        "## Notes",
        "",
        "- CPU backend currently provides the baseline runtime smoke path.",
        "- GPU backends are currently discovery-aware and runtime-aware but not yet CI-executed on dedicated hardware.",
        "- Future workflows should upload runtime capability artifacts per runner.",
    ])

    OUTPUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
