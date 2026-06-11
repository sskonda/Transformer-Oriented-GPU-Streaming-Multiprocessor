# Results

The checked CSV files were extracted from ModelSim Intel FPGA Starter 20.1
simulation logs on June 11, 2026, using the default architecture parameters
and seed 17.

## GEMM

| Metric | Value |
| --- | ---: |
| Counted cycles | 32 |
| Issued instructions | 4 |
| Tensor operations completed | 1 |
| Prefetch requests | 1 |
| Tile-wait cycles | 25 |
| Tensor busy cycles | 3 |
| Tensor busy utilization | 9.375% |
| Bank conflicts | 0 |

## Scheduler Comparison

| Policy | Cycles | Tile wait | Tensor busy utilization |
| --- | ---: | ---: | ---: |
| Round robin | 40 | 33 | 7.5% |
| Greedy | 40 | 33 | 7.5% |
| Memory aware | 40 | 33 | 7.5% |

The policies tie on this small two-warp smoke workload. This result validates
counter extraction and policy selection but does not establish a performance
ranking.

These are architectural simulation counters. They are not clock-frequency,
synthesis, area, power, FPGA, or silicon measurements. Raw CSV data and
regeneration commands are in `results/`.
