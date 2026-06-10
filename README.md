# WarpForge

WarpForge is a transformer-oriented GPU Streaming Multiprocessor written in synthesizable SystemVerilog and verified with UVM, directed tests, constrained-random stimulus, functional coverage, and SystemVerilog Assertions.

The design focuses on architecture-level interactions between SIMT warp scheduling, register dependency tracking, banked shared memory, asynchronous tile prefetching, and a low-precision tensor matrix-multiply datapath.

## Status

The repository is under active milestone-based development. See [PROJECT_PLAN.md](PROJECT_PLAN.md) for the implementation and verification roadmap.

## Planned Architecture

- Parameterized warp scheduler with round-robin, greedy, and memory-aware policies
- Per-warp lifecycle and wait-state tracking
- Register scoreboard with deterministic simultaneous set/clear behavior
- Signed INT8 tensor matrix-multiply unit with configurable dimensions and latency
- Banked shared memory with deterministic conflict handling
- Asynchronous tile prefetch request queue and tile-valid tracking
- Per-warp instruction storage and scalar execution path
- Architecture-level performance counters
- UVM environment, assertions, coverage, and regression support

## Coding Methodology

WarpForge follows the synthesizable SystemVerilog methodology in the [ARC-Lab-UF SystemVerilog tutorial](https://github.com/ARC-Lab-UF/sv-tutorial): design the intended circuit first, separate combinational and sequential behavior, use `always_comb` and `always_ff` consistently, and make reset, latency, and same-cycle priority rules explicit.

## Repository Layout

```text
rtl/        Synthesizable SystemVerilog
tb/         UVM, interfaces, directed testbench code, and assertions
sim/        Filelists and simulator scripts
tests/      Regression descriptions and test data
docs/       Architecture and verification documentation
```

## License

WarpForge is released under the MIT License.
