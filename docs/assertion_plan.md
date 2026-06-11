# Assertion Plan

Assertions are instantiated under `ifndef SYNTHESIS` so synthesis filelists
can exclude verification logic.

| Block | Key properties |
| --- | --- |
| Scoreboard | Known reset state, legal indices, source-stall consistency, clear-wins behavior |
| Scheduler | Legal policy and pointer, selected warp ready and in range, no issue during reset |
| Tensor core | Legal parameters, accepted-input latency, valid stability under backpressure, known control |
| Shared memory | Legal addresses, conflict consistency, response validity, known control |
| Prefetch | Queue range, legal dequeue/enqueue, no forbidden overwrite, known valid/ready state |
| Instruction queue | PC and load ranges, accepted-issue-only advance, END halt, illegal detection |
| Scalar ALU | Legal opcode acceptance, latency, output stability, known valid |
| Performance counters | Monotonic fields, legal completed-warp count, known state |
| Top level | Accepted legal issue, active warp selection, END/error transition, legal done, known status |

The local ModelSim Starter flow compiles these properties but does not execute
concurrent assertions under its license. Assertion execution requires Questa,
VCS, Xcelium, or another capable simulator. No assertion pass percentage is
claimed from the local run.
