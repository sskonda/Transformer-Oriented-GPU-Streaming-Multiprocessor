# WarpForge SM Microarchitecture

`warpforge_top` integrates program storage, warp control, dependency tracking,
scalar execution, tensor execution, asynchronous tile prefetch, banked shared
memory, and performance counters.

## Program launch

Instructions are loaded per warp before execution. Scalar registers can also
be initialized through the verification load interface. A `start` pulse
captures the set of warps that have a valid instruction at PC zero and
activates those warps. `clear` restarts loaded programs, clears architectural
control state and registers, and preserves instruction memory contents.

## Issue and dependencies

The scheduler sees one current instruction per active warp. Source-register
and destination-register hazards block issue through the scoreboard. Scalar
and tensor instructions set the destination busy bit when accepted. Writeback
clears it. Tensor writeback has deterministic priority over scalar writeback
when both complete in one cycle.

`ENABLE_OPERAND_FORWARDING` optionally allows a scalar instruction to consume
a same-cycle writeback value. Write-after-write hazards remain blocked in both
modes.

## Instruction behavior

| Opcode | Integrated behavior |
| --- | --- |
| `NOP` | Advances the warp PC. |
| `ALU_ADD` | Writes `src0 + src1` to `dst`. |
| `ALU_MUL` | Writes the low scalar-width product to `dst`. |
| `ALU_MAD` | Writes `src0 * src1 + src2` to `dst`. |
| `PREFETCH_TILE` | Enqueues one packed tensor tile from the immediate word address. |
| `WAIT_TILE` | Blocks until the selected warp-local tile is valid. |
| `TENSOR_MMA` | Multiplies the selected tile matrices and writes element `[0][0]` to `dst`. |
| `BARRIER` | Waits until every launched, nonterminal warp reaches the barrier. |
| `END` | Marks the warp complete. |
| Illegal encoding | Marks the warp in error and increments the illegal counter. |

The complete tensor matrix is also emitted on the tensor result interface for
verification and workload checking.

## Tile format

A tile contains matrix A in row-major order followed by matrix B in row-major
order. Elements are signed INT8 values packed from the least-significant byte
upward in each 32-bit word. The default 4 x 4 x 4 operation therefore uses
eight words: four for A and four for B.

Global memory addresses are word addresses. Each accepted global request
returns one word through the valid/ready response channel. Prefetch writes the
same word into banked shared memory and the tensor tile buffer.

## Completion

`busy` remains asserted while any launched warp or execution transaction is
active. `done` asserts after every launched warp reaches `DONE` or `ERROR` and
all outstanding scalar, tensor, scoreboard, and prefetch work drains.
