# Warp Scheduler

The scheduler builds a ready vector from active state, instruction validity,
scoreboard dependencies, tile waits, tensor availability, and prefetch
backpressure. A warp is selectable only when every blocking condition is
clear.

## Round Robin

Round robin searches from a registered pointer and wraps at `NUM_WARPS`.
The pointer advances to the entry after the selected warp only when issue is
accepted. Backpressure therefore does not skip a warp.

## Greedy

Greedy selects the lowest numbered ready warp every cycle. It has a short,
deterministic priority path but can starve higher-numbered warps if a lower
warp remains continuously ready.

## Memory Aware

Memory-aware scheduling forms `preferred_ready = ready & tile_preferred`.
When at least one preferred warp exists, the scheduler greedily chooses among
ready `TENSOR_MMA` warps with valid tiles. Otherwise it falls back to ordinary
greedy selection.

The policy does not yet predict bank conflicts, prefetch completion time, or
long-term starvation. The checked scheduler smoke workload ties across all
three policies, so it demonstrates policy correctness but not a performance
gain.

## Verification

Direct tests check ready filtering, round-robin wrap, greedy priority, and
tile preference. Integrated UVM tests run the same mixed scalar/tensor
workload under each policy and emit comparable performance records.
