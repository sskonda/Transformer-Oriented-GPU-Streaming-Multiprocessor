# Tensor Core

The tensor core computes signed `M x K` by `K x N` matrix products with
`INPUT_WIDTH` operands and `ACC_WIDTH` results. The default configuration is
signed INT8 input, signed INT32 accumulation, and 4 x 4 x 4 tiles.
To prevent silent reduction overflow in parameterized instances, `ACC_WIDTH`
must be at least `2 * INPUT_WIDTH + ceil(log2(K))`.

## Architecture modes

`TENSOR_ARCH_TREE` uses a balanced combinational reduction tree followed by
a one-entry elastic output register. This mode is useful for small dimensions
and latency-oriented experiments, but the complete multiply-reduction path
between the input and output register is combinational.

`TENSOR_ARCH_PIPELINED_TREE` is the default. It registers the products and
every balanced reduction level. The number of stages is:

```text
1 + ceil(log2(K))
```

Non-power-of-two `K` values are padded with zero leaves. For the default
`K = 4`, the datapath has three stages: products, pairwise sums, and final
sums. Each stage is elastic, so completed output remains stable while
`out_valid` is asserted and `out_ready` is deasserted.

`TENSOR_ARCH_SYSTOLIC` is reserved for future implementation. Selecting it
causes an elaboration-time failure rather than silently using a different
architecture.

## Handshake

An operation is accepted when `in_valid && in_ready` is true on a rising
clock edge. A result is transferred when `out_valid && out_ready` is true.
The pipelined tree accepts one operation per cycle when downstream flow is
uninterrupted. Backpressure propagates through all stages without dropping or
reordering results.

`clear` and `rst` flush pipeline validity. Datapath registers are not reset
because invalid entries are ignored.

## Verification

The direct test checks identity, signed, zero, and maximum positive operand
cases. It also checks derived latency, back-to-back throughput, output
stability under backpressure, registered tree mode, and reset while an
operation is in flight. A parameter-limit test elaborates and executes both
architectures with `K = 1`, `K = 3`, and `K = 5`, covering the minimum and
non-power-of-two reduction cases. Both tensor modes run the file-driven GEMM
workload.
