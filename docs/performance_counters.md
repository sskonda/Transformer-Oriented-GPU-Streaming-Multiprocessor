# Performance Counters

`perf_counters` records architecture events supplied by the integrated Streaming Multiprocessor.

## Cycle Counters

- `total_cycles`: cycles while execution counting is enabled
- `scheduler_stall_cycles`: active cycles with no legal issue
- `scoreboard_stall_cycles`: cycles with at least one dependency-stalled warp
- `tile_wait_cycles`: cycles with at least one warp waiting for a tile
- `tensor_wait_cycles`: cycles blocked on tensor availability
- `prefetch_stall_cycles`: cycles blocked on prefetch availability
- `tensor_busy_cycles`: cycles while the tensor datapath is occupied

## Transaction Counters

- `issued_instructions`
- `scalar_instructions`
- `tensor_instructions`
- `prefetch_instructions`
- `tensor_accepted`
- `tensor_completed`
- `bank_conflicts`
- `prefetch_requests`
- `prefetch_stalls`
- `completed_warps`
- `illegal_instructions`

Every field increments only from an explicit event input. Counters are monotonic until reset or clear. `completed_warps` saturates at `NUM_WARPS` so an integration error cannot expose an architecturally impossible value.

`issued_instructions` counts every accepted architectural instruction. The
`prefetch_instructions` and `prefetch_requests` fields count requests actually
dispatched to and accepted by the prefetch engine, so an idempotent
already-valid `PREFETCH_TILE` increments only `issued_instructions`.

Tensor utilization can be calculated as `tensor_busy_cycles / total_cycles` or `tensor_accepted / total_cycles`, depending on whether occupancy or accepted-operation rate is desired.
