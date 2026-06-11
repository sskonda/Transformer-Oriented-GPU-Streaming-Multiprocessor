# Performance Results

The CSV files in this directory are extracted from actual ModelSim Intel FPGA
Starter Edition 20.1 simulations of the default WarpForge configuration. They
are architectural simulation counters, not synthesis, timing, power, FPGA, or
silicon measurements.

Regenerate the checked examples:

```powershell
.\sim\scripts\run_modelsim.ps1 -Test workload_gemm_test -Seed 17
.\sim\scripts\run_modelsim.ps1 -Test scheduler_round_robin_test -Seed 17
.\sim\scripts\run_modelsim.ps1 -Test scheduler_greedy_test -Seed 17
.\sim\scripts\run_modelsim.ps1 -Test scheduler_memory_aware_test -Seed 17

python tools/collect_perf.py `
  build/logs/workload_gemm_test_17.log `
  -o results/example_gemm_results.csv `
  --workload gemm

python tools/collect_perf.py `
  build/logs/scheduler_round_robin_test_17.log `
  build/logs/scheduler_greedy_test_17.log `
  build/logs/scheduler_memory_aware_test_17.log `
  -o results/example_scheduler_comparison.csv
```

Tensor utilization is `tensor_busy_cycles / total_cycles`. The scheduler
comparison uses the integrated two-warp smoke workload. It is intentionally
small and should not be treated as a general performance ranking. A policy
that ties on this workload has not demonstrated an advantage.

In the checked seed-17 sample, all three policies complete in 40 cycles with
33 aggregate tile-wait cycles and 7.5 percent tensor busy-cycle utilization.
The result validates policy selection and counter collection, but does not
show a policy performance advantage. Larger overlapping-prefetch workloads
are needed for a meaningful memory-aware scheduling study.
