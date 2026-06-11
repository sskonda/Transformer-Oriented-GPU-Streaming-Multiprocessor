# Verification Plan

WarpForge uses layered verification so block-level arithmetic and protocol
failures are separated from integrated architectural failures.

## Unit verification

Self-checking direct tests cover the scoreboard, scheduler, tensor core,
shared memory, prefetch engine, instruction queue, scalar ALU, performance
counters, and integrated top level. These tests use deterministic clocks and
drive inputs away from the active clock edge.

## Assertions

Assertion modules check reset state, valid/ready protocol behavior, index
ranges, monotonic counters, stable backpressured outputs, dependency state,
legal issue, and top-level completion invariants. ModelSim Intel FPGA Starter
Edition can compile these assertions but does not execute concurrent
assertions. Full assertion execution requires Questa or another compatible
commercial simulator.

## UVM environment

The integrated UVM environment contains:

- `warpforge_agent`: active sequencer, clocking-block driver, and monitor
- `warpforge_driver`: deterministic reset, program/register loading, start
  control, and a reactive word-addressed global-memory model
- `warpforge_monitor`: issue, memory, result, warp terminal, and counter events
- `warpforge_ref_model`: per-warp PCs, instruction memory, scalar registers,
  dependency state, tile data, scalar arithmetic, and tensor golden results
- `warpforge_scoreboard`: scalar, tensor, and terminal-state comparisons
- `warpforge_coverage`: event, opcode, scheduler, warp, sign, zero, and
  scheduler-policy by opcode coverage
- `warpforge_env`: analysis connectivity between monitor, model, scoreboard,
  and coverage

The `sanity_smoke_test` runs the same two-warp architectural scenario as the
direct top-level test. One warp prefetches and executes a signed INT8 tensor
operation. A second warp executes a dependent scalar instruction chain.

The checked ModelSim regression runs 22 representative targets: seven direct
unit benches, the file-driven GEMM workload, and fourteen integrated UVM
tests. Named aliases in `sim/test_manifest.csv` map more detailed test-plan
names onto the self-checking unit benches that contain those cases.

## Simulator capability

ModelSim Intel FPGA Starter Edition can run the deterministic UVM environment
when `WARPFORGE_DISABLE_COVERAGE` is defined. Its license does not execute user
covergroups or constrained randomization. Coverage-enabled source is compiled
separately for portability, while coverage collection and constrained-random
execution target Questa, VCS, or Xcelium.

No coverage percentage is claimed until a coverage-capable simulator produces
the corresponding database.
