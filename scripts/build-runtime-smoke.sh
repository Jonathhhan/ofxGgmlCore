#!/usr/bin/env bash

set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$root_dir/build/runtime-smoke"
output="$build_dir/runtime_smoke"

mkdir -p "$build_dir"

if [ ! -f "$root_dir/libs/ggml/include/ggml.h" ]; then
  echo "Missing ggml headers. Run scripts/setup-ggml.sh first."
  exit 77
fi

if [ ! -f "$root_dir/libs/ggml/lib/libggml.a" ] || [ ! -f "$root_dir/libs/ggml/lib/libggml-base.a" ] || [ ! -f "$root_dir/libs/ggml/lib/libggml-cpu.a" ]; then
  echo "Missing ggml static libraries. Run scripts/setup-ggml.sh first."
  exit 77
fi

cxx="${CXX:-c++}"

"$cxx" -std=c++17 \
  -I"$root_dir/src" \
  -I"$root_dir/libs/ggml/include" \
  "$root_dir/tools/runtime-smoke/runtime_smoke.cpp" \
  "$root_dir/src/core/ofxGgmlRuntime.cpp" \
  "$root_dir/src/compute/ofxGgmlGraph.cpp" \
  "$root_dir/src/compute/ofxGgmlTensor.cpp" \
  "$root_dir/libs/ggml/lib/libggml.a" \
  "$root_dir/libs/ggml/lib/libggml-base.a" \
  "$root_dir/libs/ggml/lib/libggml-cpu.a" \
  -fopenmp -lpthread -ldl \
  -o "$output"

"$output" --backend cpu --require-backend
