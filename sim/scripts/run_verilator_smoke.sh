#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILELIST_DIR="$ROOT_DIR/sim/filelists"
BUILD_DIR="$ROOT_DIR/build/verilator/workload_gemm"

if ! command -v verilator >/dev/null 2>&1; then
  echo "verilator is required for this smoke flow" >&2
  exit 2
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
pushd "$FILELIST_DIR" >/dev/null
verilator \
  --binary \
  --timing \
  --Wall \
  -Wno-fatal \
  --top-module workload_gemm_tb \
  --Mdir "$BUILD_DIR" \
  -f workload_gemm_unit.f
"$BUILD_DIR/Vworkload_gemm_tb"
popd >/dev/null
