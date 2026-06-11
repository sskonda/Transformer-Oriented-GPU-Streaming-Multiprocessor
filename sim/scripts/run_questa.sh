#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILELIST_DIR="$ROOT_DIR/sim/filelists"
BUILD_DIR="$ROOT_DIR/build/questa"
LOG_DIR="$ROOT_DIR/build/logs"
TEST="${TEST:-sanity_smoke_test}"
SEED="${SEED:-1}"
UVM_HOME="${UVM_HOME:-}"
WORK_LIB="$BUILD_DIR/work"
LOG_FILE="$LOG_DIR/${TEST}_${SEED}.log"

mkdir -p "$BUILD_DIR" "$LOG_DIR"
rm -rf "$WORK_LIB"
vlib "$WORK_LIB"

case "$TEST" in
  scoreboard_dependency_test|scoreboard_simultaneous_set_clear_test)
    TOP=scoreboard_tb
    MODE=unit
    ;;
  tensor_core_basic_test|tensor_core_signed_test|tensor_core_zero_test|tensor_core_extreme_test|tensor_core_back_to_back_test|tensor_core_reset_mid_operation_test)
    TOP=tensor_core_tb
    MODE=unit
    ;;
  shared_memory_basic_test|shared_memory_bank_conflict_test|shared_memory_read_after_write_test)
    TOP=shared_memory_tb
    MODE=unit
    ;;
  prefetch_basic_test|prefetch_queue_full_test|prefetch_reset_mid_request_test)
    TOP=async_tile_prefetch_tb
    MODE=unit
    ;;
  instruction_queue_load_issue_test)
    TOP=instruction_queue_tb
    MODE=unit
    ;;
  scalar_alu_basic_test)
    TOP=scalar_alu_tb
    MODE=unit
    ;;
  perf_counter_basic_test)
    TOP=perf_counters_tb
    MODE=unit
    ;;
  workload_gemm_test)
    TOP=workload_gemm_tb
    MODE=unit
    ;;
  *)
    TOP=tb_top
    MODE=uvm
    ;;
esac

pushd "$FILELIST_DIR" >/dev/null
if [[ "$MODE" == "unit" ]]; then
  vlog -sv -work "$WORK_LIB" +define+SYNTHESIS -f all.f
  vsim -c -lib "$WORK_LIB" "$TOP" \
    -l "$LOG_FILE" \
    -do "$ROOT_DIR/sim/questa/run.do"
else
  if [[ -z "$UVM_HOME" || ! -f "$UVM_HOME/uvm_pkg.sv" ]]; then
    echo "UVM_HOME must point to a UVM source directory." >&2
    exit 2
  fi
  vlog -sv -work "$WORK_LIB" \
    +define+SYNTHESIS \
    +define+WARPFORGE_ENABLE_CONSTRAINED_RANDOM \
    "+incdir+$UVM_HOME" \
    "$UVM_HOME/uvm_pkg.sv" \
    -f uvm.f
  vsim -c -lib "$WORK_LIB" "$TOP" \
    "+UVM_TESTNAME=$TEST" \
    "+ntb_random_seed=$SEED" \
    "+SEED=$SEED" \
    -l "$LOG_FILE" \
    -do "$ROOT_DIR/sim/questa/run.do"
fi
popd >/dev/null

if grep -Eq 'UVM_(ERROR|FATAL)[[:space:]]*:[[:space:]]*[1-9]' "$LOG_FILE"; then
  echo "FAIL: $TEST seed=$SEED"
  exit 1
fi

echo "PASS: $TEST seed=$SEED"
