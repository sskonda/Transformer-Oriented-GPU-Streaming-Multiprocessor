# WarpForge Design And Verification Audit

Date: June 13, 2026

## Executive Summary

This audit reviewed the repository history, RTL, testbenches, UVM structure,
workloads, scripts, documentation, and performance tooling. It then exercised
all direct self-checking simulations available on this machine.

Five design defects were confirmed and fixed:

1. A warp could issue beyond a barrier before all participating warps arrived.
2. Tree tensor mode could deadlock at the integrated top-level handshake.
3. Repeating a prefetch for an already-valid tile could stall forever.
4. Invalid prefetch IDs could index outside parameterized state arrays.
5. Parameterized tensor instances could silently select an accumulator too
   narrow for the complete reduction.

The audit also corrected a malformed performance log record, removed a false
combinational-loop lint path, made arithmetic widths explicit, and improved
Icarus syntax portability.

After the fixes, all 13 Verilator direct targets passed. Every compiled target
was then executed 100 times, for 1,300 successful repeated simulations. Nine
Python tests, three software reference workloads, performance extraction, shell
syntax checks, and integrated RTL lint also passed.

## Repository Scope

The repository contains approximately 11,762 lines across RTL, verification,
tools, workloads, and simulation support. The checked history spans June 9-11,
2026 and shows a staged implementation:

- Common RTL, scoreboard, warp state, scheduler, tensor, and shared memory
- Prefetch, scalar issue/execution, and performance counters
- Integrated streaming multiprocessor and UVM environment
- Directed and constrained-random tests
- Assembly, workload, performance, CI, and documentation support

The integrated design consists of per-warp instruction queues, warp lifecycle
and barrier control, three scheduling policies, a dependency scoreboard,
scalar register file and ALU, asynchronous tile prefetch, banked shared memory,
tensor tile storage, two tensor architectures, deterministic writeback, and
architectural counters.

## Machine And Tools

- CPU: Intel Core i7-1185G7, 4 cores / 8 threads
- Memory: 31 GiB
- Icarus Verilog: 12.0
- Verilator: 5.020, installed rootlessly for this audit
- Python tooling: pytest and repository scripts
- Commercial simulator: unavailable
- NVIDIA GPU: unavailable and not required for RTL simulation

## Confirmed Findings

### F1: Barrier Did Not Block Scheduler Eligibility

Severity: High

The run-control block tracked barrier arrivals, but the scheduler did not use
that state when constructing its ready mask. Under greedy scheduling, a
low-numbered warp could issue its barrier and then continue issuing subsequent
instructions while another warp had not reached the barrier.

Fix:

- Added `barrier_wait` to scheduler eligibility filtering.
- Wired the signal through the integrated top.
- Extended scheduler assertions.
- Added a greedy two-warp integrated test that fails if warp 0 issues beyond
  its barrier before warp 1 arrives.

### F2: Integrated Tree Tensor Mode Could Deadlock

Severity: High

Tree mode originally exposed a combinational result/ready path. At the
top-level, tensor readiness depended on metadata readiness, while metadata
creation depended on accepting the tensor operation. This circular handshake
prevented architectural acceptance.

Fix:

- Added a one-entry elastic output register to tree mode.
- Defined normal valid/ready behavior and stable backpressure semantics.
- Updated tensor assertions and direct tests.
- Added a file-driven integrated GEMM test using tree mode.

Result:

- Pipelined GEMM: 32 cycles, 3 tensor-busy cycles.
- Tree GEMM: 30 cycles, 1 tensor-busy cycle.
- Both produce the complete expected 4x4 matrix.

### F3: Duplicate Valid-Tile Prefetch Could Stall Forever

Severity: High

The prefetch engine correctly rejects a request for an already-valid tile when
overwrite is disabled. However, the instruction issue path kept retrying that
request and had no architectural completion or error path, so a repeated
prefetch instruction could deadlock the warp.

Fix:

- A program-level prefetch of an already-valid tile now retires as an
  idempotent no-op.
- Duplicate pending requests still wait for the original transfer.
- Added an integrated test that requires two prefetch instructions to retire
  while observing only one memory transfer and one prefetch request count.

### F4: Invalid Prefetch IDs Could Cause Out-Of-Bounds Access

Severity: Medium

For non-power-of-two parameter values, encoded warp or tile IDs can represent
values outside the implemented arrays. The prefetch request and invalidate
paths previously indexed state before proving the IDs were in range.

Fix:

- Added explicit request and invalidate index checks.
- Array accesses now occur only after both IDs are valid.
- Invalid requests remain backpressured and cannot corrupt tile state.

### F5: Accumulator Width Contract Ignored Reduction Growth

Severity: Medium

The tensor wrapper only required `ACC_WIDTH >= 2 * INPUT_WIDTH`. That covers
one signed product, but a sum of `K` products needs additional growth bits.
Some legal-looking parameter combinations could therefore overflow silently.

Fix:

- Elaboration now requires:

  `ACC_WIDTH >= 2 * INPUT_WIDTH + ceil(log2(K))`

- Added parameter-limit execution for `K=1`, `K=3`, and `K=5` in both tree
  and pipelined-tree modes.

### F6: Performance Record Was Not Machine-Parseable

Severity: Low

The GEMM test constructed its format through concatenated `$sformatf` calls.
Under Verilator this emitted the packed record as a large decimal value, so
`collect_perf.py` could not extract metrics.

Fix:

- Replaced the construction with one literal `$display` format.
- Confirmed extraction to CSV.

Extracted default GEMM result:

- Cycles: 32
- Issued instructions: 4
- Tensor operations: 1
- Prefetch requests: 1
- Tile-wait cycles: 25
- Tensor-busy cycles: 3
- Tensor utilization: 9.375%

### F7: Lint And Portability Defects Obscured Real Results

Severity: Low

The original top-level lint contained width diagnostics and a false
`UNOPTFLAT` path through issue/scoreboard logic. Icarus also rejected several
`inside` expressions used in synthesizable logic.

Fix:

- Split issue query generation from scoreboard/wait computation.
- Reworked the scalar ready chain into one explicit backward combinational
  calculation.
- Added explicit casts and sized constants across counters, queues, memory,
  scheduler, prefetch, tile storage, and top-level address calculations.
- Replaced RTL `inside` predicates with explicit equality helpers.

Final integrated lint exits successfully with no width, truncation, expansion,
or combinational-loop diagnostics. Remaining warnings are unused debug signals,
intentional partial-word intermediates, and unused package parameters.

## Verification Results

### Verilator Direct Regression

All targets passed:

- Scoreboard
- Scheduler
- Tensor core
- Tensor parameter limits
- Shared memory
- Asynchronous prefetch
- Instruction queue
- Scalar ALU
- Performance counters
- Integrated top
- Pipelined-tree GEMM
- Tree GEMM
- Integrated barrier and duplicate-prefetch boundaries

Each binary was executed 100 times after compilation. Result: 1,300/1,300
successful repeated simulations.

### Python And Workloads

- `pytest -q tools`: 9 passed
- GEMM reference: passed
- Tiny transformer integer attention reference: passed
- Reduced MNIST-style MLP reference: passed
- Performance CSV extraction: passed
- Shell script syntax: passed
- Git whitespace/error check: passed

### Icarus Cross-Check

Executed successfully:

- Scheduler
- Shared memory
- Performance counters

Icarus 12.0 could not elaborate tensor, prefetch, or integrated top benches
because of unsupported dynamic indexing into packed multidimensional arrays.
Two of those elaborations terminated inside the Icarus compiler. The same RTL
and benches compile and execute under Verilator, so these failures are
classified as Icarus backend limitations rather than observed design failures.

## Residual Limits And Risks

The following were not validated on this machine:

- UVM execution, native constrained randomization, functional coverage, and
  concurrent assertion execution, because no licensed UVM-capable commercial
  simulator was available.
- Formal proof of protocol safety, liveness, or deadlock freedom.
- FPGA/ASIC synthesis, static timing, area, power, CDC, reset-domain, or gate
  simulation.
- The reserved systolic tensor architecture, which intentionally fails
  elaboration because it is not implemented.
- Large-model inference, caches, coalescing, multiple outstanding global
  transactions, full attention lowering, or architectural storage of complete
  tensor results.
- Broad parameter sweeps outside the tensor `K` limits tested here. Several
  package-level dimensions define packed instruction and interface types and
  therefore require whole-design recompilation to change.

Repeated deterministic simulations test stability but do not replace
many-seed constrained-random testing or formal liveness analysis.

## Recommended Next Work

1. Run the existing UVM suite with Questa, VCS, or Xcelium and collect
   assertion and functional coverage.
2. Add formal properties for barrier release, scoreboard eventual clear,
   prefetch request completion, and valid/ready stability.
3. Add synthesis constraints and compare tree versus pipelined-tree timing,
   area, and power.
4. Add package-configuration builds for non-power-of-two warp/tile counts and
   varied memory bank counts.
5. Add randomized memory response latency and backpressure to the direct
   Verilator flow so open-source CI can exercise more liveness scenarios.

## Conclusion

The default WarpForge configuration now passes every direct executable test
available on this machine, including newly added tests for the three confirmed
deadlock/correctness paths and tensor parameter limits. The design remains an
educational architecture model, not a production GPU, but its direct
simulation baseline is materially stronger and its remaining unverified areas
are explicitly bounded above.
