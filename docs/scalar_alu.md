# Scalar ALU

`scalar_alu` implements signed `ALU_ADD`, `ALU_MUL`, and `ALU_MAD` operations. Results are truncated to the configured scalar data width.

The datapath uses an elastic valid/ready pipeline. `LATENCY` defines the minimum latency when the downstream interface is ready. Output backpressure stalls the pipeline and extends latency without changing valid output data or writeback metadata.

Warp ID and destination register index travel with the result so the integrated writeback path can update the correct register file entry and clear the matching scoreboard dependency.

Reset and clear invalidate pipeline stages. Datapath payload registers are not reset because they are ignored while valid is low.
