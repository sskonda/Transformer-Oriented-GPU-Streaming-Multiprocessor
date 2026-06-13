module tensor_core_sva #(
  parameter int unsigned M = warpforge_pkg::TENSOR_M,
  parameter int unsigned N = warpforge_pkg::TENSOR_N,
  parameter int unsigned ACC_WIDTH = warpforge_pkg::TENSOR_ACC_WIDTH,
  parameter int unsigned PIPELINE_STAGES =
      warpforge_pkg::TENSOR_PIPELINE_LATENCY,
  parameter warpforge_pkg::tensor_arch_e TENSOR_ARCH =
      warpforge_pkg::TENSOR_ARCH_PIPELINED_TREE
) (
  input logic clk,
  input logic rst,
  input logic clear,
  input logic in_valid,
  input logic in_ready,
  input logic out_valid,
  input logic out_ready,
  input wire logic signed [M-1:0][N-1:0][ACC_WIDTH-1:0] matrix_c
);
  import warpforge_pkg::*;

  assert property (@(posedge clk)
    rst || clear |=> !out_valid);

  assert property (@(posedge clk) disable iff (rst || clear)
    out_valid && !out_ready |=> out_valid && $stable(matrix_c));

  assert property (@(posedge clk) disable iff (rst || clear)
    !$isunknown({in_ready, out_valid}));

  if (TENSOR_ARCH == TENSOR_ARCH_TREE) begin : g_tree
    assert property (@(posedge clk) disable iff (rst || clear)
      in_valid && in_ready |=> out_valid);
  end

  if (
    TENSOR_ARCH == TENSOR_ARCH_PIPELINED_TREE &&
    PIPELINE_STAGES > 0
  ) begin : g_pipeline
    assert property (@(posedge clk) disable iff (rst || clear)
      in_valid && in_ready |-> ##[1:$] out_valid);
  end

endmodule
