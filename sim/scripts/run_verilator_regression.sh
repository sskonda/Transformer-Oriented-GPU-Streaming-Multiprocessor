#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILELIST_DIR="$ROOT_DIR/sim/filelists"
BUILD_ROOT="$ROOT_DIR/build/verilator/regression"
LOG_DIR="$ROOT_DIR/build/logs"
VERILATOR="${VERILATOR:-verilator}"

if ! command -v "$VERILATOR" >/dev/null 2>&1; then
  echo "verilator is required for this regression" >&2
  exit 2
fi

TESTS=(
  "scoreboard_tb:scoreboard_unit.f"
  "scheduler_tb:scheduler_unit.f"
  "tensor_core_tb:tensor_unit.f"
  "tensor_core_parameter_tb:tensor_parameter_unit.f"
  "shared_memory_tb:shared_memory_unit.f"
  "async_tile_prefetch_tb:prefetch_unit.f"
  "instruction_queue_tb:instruction_queue_unit.f"
  "scalar_alu_tb:scalar_alu_unit.f"
  "perf_counters_tb:perf_counters_unit.f"
  "warpforge_top_tb:top_unit.f"
  "workload_gemm_tb:workload_gemm_unit.f"
  "workload_gemm_tree_tb:workload_gemm_unit.f"
  "warpforge_control_tb:control_unit.f"
)

mkdir -p "$BUILD_ROOT" "$LOG_DIR"
pushd "$FILELIST_DIR" >/dev/null
for test_spec in "${TESTS[@]}"; do
  top="${test_spec%%:*}"
  filelist="${test_spec#*:}"
  build_dir="$BUILD_ROOT/$top"
  log_file="$LOG_DIR/${top}_verilator.log"

  rm -rf "$build_dir"
  "$VERILATOR" \
    --binary \
    --timing \
    --Wall \
    -Wno-fatal \
    --top-module "$top" \
    --Mdir "$build_dir" \
    -f "$filelist"
  "$build_dir/V$top" | tee "$log_file"
done
popd >/dev/null

echo "PASS: WarpForge Verilator direct regression"
