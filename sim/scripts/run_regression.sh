#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="${RUNNER:-$ROOT_DIR/sim/scripts/run_questa.sh}"
SEED="${SEED:-1}"

TESTS=(
  scoreboard_dependency_test
  tensor_core_basic_test
  shared_memory_basic_test
  prefetch_basic_test
  instruction_queue_load_issue_test
  scalar_alu_basic_test
  perf_counter_basic_test
  workload_gemm_test
  sanity_smoke_test
  scheduler_round_robin_test
  scheduler_greedy_test
  scheduler_memory_aware_test
  top_single_warp_gemm_test
  top_multi_warp_contention_test
  barrier_synchronization_test
  reset_mid_operation_test
  illegal_instruction_test
  constrained_random_instruction_test
  random_multi_warp_test
  random_memory_latency_test
  random_backpressure_test
  long_regression_test
)

for test_name in "${TESTS[@]}"; do
  TEST="$test_name" SEED="$SEED" "$RUNNER"
done

echo "PASS: WarpForge regression seed=$SEED"
