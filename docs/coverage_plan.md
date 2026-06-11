# Functional Coverage Plan

## Implemented Covergroup

`warpforge_coverage` samples monitor observations and includes:

- Observation kind
- Opcode
- Scheduler policy
- Warp ID
- Negative scalar or tensor result
- Zero scalar or tensor result
- Scheduler-policy by opcode cross

The observation-kind bins include reset, clear, loads, global-memory traffic,
issue, scalar result, tensor result, warp done, warp error, and top-level done.

## Planned Expansion

The following coverage is not yet represented by dedicated coverpoints:

- Warp-state transitions
- Scoreboard simultaneous set and clear
- Prefetch queue empty, partial, and full levels
- Shared-memory conflict and no-conflict classes
- Reset during each execution subsystem
- Explicit multi-warp contention degree
- Tensor signed-zero-extreme class crosses

These behaviors have directed tests, but directed testing is not a substitute
for measured functional coverage.

## Simulator Status

Coverage-enabled UVM source compiles in the local environment. ModelSim Intel
FPGA Starter cannot execute user covergroups, so no coverage database or
percentage is published. Coverage collection targets a licensed Questa, VCS,
or Xcelium run.
