# WarpForge Project Plan

## Project Overview

WarpForge is a simplified transformer-oriented GPU Streaming Multiprocessor. It is intended to demonstrate GPU microarchitecture, timing-aware RTL design, and rigorous SystemVerilog verification in a portfolio-quality public repository.

## Architecture Summary

The Streaming Multiprocessor maintains multiple independent warps and issues one instruction per cycle when a legal warp is available. A scheduler filters inactive, completed, dependency-stalled, tile-stalled, and resource-stalled warps. Scalar operations use a compact ALU path, while matrix operations use a signed low-precision tensor datapath. A queued prefetch engine transfers tiles from a modeled global-memory interface into banked shared memory. Performance counters expose utilization and stall behavior.

## Module List

- `warpforge_pkg`: shared parameters, enums, structs, types, and utility functions
- `fifo`: reusable bounded queue
- `valid_pipeline`: valid-bit delay pipeline
- `ram_sdp`: portable simple dual-port RAM wrapper
- `scoreboard`: per-warp register dependency tracking
- `warp_state_table`: warp lifecycle and wait-state tracking
- `warp_scheduler`: configurable warp selection policy
- `tensor_core`: parameterized signed matrix multiply
- `shared_memory`: banked scratchpad and conflict detection
- `async_tile_prefetch`: queued tile transfer engine
- `instruction_queue`: per-warp instruction storage and program counters
- `scalar_alu`: scalar arithmetic path
- `perf_counters`: architecture event counters
- `warpforge_top`: integrated Streaming Multiprocessor

## Verification Strategy

Verification is layered:

1. Unit-level directed testbenches validate deterministic block behavior.
2. Assertions check protocol, range, reset, and same-cycle invariants.
3. UVM sequences drive integrated instruction and memory traffic.
4. A reference model predicts architectural state and tensor results.
5. Functional coverage measures opcodes, policies, state transitions, stalls, conflicts, reset scenarios, and arithmetic corner cases.
6. Seeded constrained-random regressions stress interleavings and backpressure.

## Milestones

- [x] Milestone 0: Repository setup
- [x] Milestone 1: Shared package and interfaces
- [x] Milestone 2: Common RTL infrastructure
- [x] Milestone 3: Scoreboard RTL and unit verification
- [ ] Milestone 4: Warp state table and scheduler
- [ ] Milestone 5: Tensor core
- [ ] Milestone 6: Shared memory
- [ ] Milestone 7: Async tile prefetch engine
- [ ] Milestone 8: Instruction issue and scalar execution
- [ ] Milestone 9: Performance counters
- [ ] Milestone 10: Top-level integration
- [ ] Milestone 11: UVM environment completion
- [ ] Milestone 12: Directed tests
- [ ] Milestone 13: Constrained-random and regression tests
- [ ] Milestone 14: Race-condition and edge-case hardening
- [ ] Milestone 15: Documentation
- [ ] Milestone 16: Final cleanup

## Commit Plan

Each completed milestone is committed directly to `main` after available checks pass. Commit authorship is configured as `Sanat Konda <sskonda04@gmail.com>`.

## Assumptions

- The default configuration uses four warps and a 4x4x4 signed INT8 tensor operation.
- Instructions are loaded through a verification-facing port before execution.
- Global memory is modeled as a valid/ready response interface rather than a complete external protocol.
- Shared-memory conflicts are detected and stalled deterministically.
- Invalid datapath contents are ignored whenever the associated valid bit is low.

## Simulator Assumptions

- Full verification targets a simulator with SystemVerilog and UVM support, such as Questa, VCS, or Xcelium.
- ModelSim Intel FPGA Starter Edition is available for RTL compilation and non-UVM smoke tests.
- Verilator support, if added, is limited to lint or a non-UVM smoke test unless full UVM capability is demonstrated.

## Risks And Mitigation

- Tensor reductions can create long combinational paths. Use an explicitly pipelined or balanced accumulation structure.
- Resetting wide datapaths can add unnecessary reset fanout. Reset valid and control state while allowing invalid datapath registers to remain unreset.
- Testbench and DUT process ordering can create races. Use interfaces, clocking blocks, sampled monitor inputs, and deterministic reset tasks.
- Portable RAM inference varies across tools. Isolate memory behavior in a wrapper and document read-during-write semantics.
- Resource arbitration can cause starvation. Verify round-robin fairness and define fallback behavior for other policies.
