module tensor_core_sva #(
  parameter int unsigned PIPELINE_LATENCY =
      warpforge_pkg::TENSOR_PIPELINE_LATENCY
) (
  input logic clk,
  input logic rst,
  input logic clear,
  input logic in_valid,
  input logic in_ready,
  input logic out_valid
);

  assert property (@(posedge clk)
    rst || clear |-> !out_valid);

  assert property (@(posedge clk) disable iff (rst || clear)
    in_ready);

  if (PIPELINE_LATENCY > 0) begin : g_latency_assertion
    assert property (@(posedge clk) disable iff (rst || clear)
      in_valid && in_ready |-> ##PIPELINE_LATENCY out_valid);
  end

  assert property (@(posedge clk) disable iff (rst || clear)
    !$isunknown({in_ready, out_valid}));

endmodule
