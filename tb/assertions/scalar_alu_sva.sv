module scalar_alu_sva #(
  parameter int unsigned DATA_WIDTH = warpforge_pkg::SCALAR_DATA_WIDTH,
  parameter int unsigned WARP_ID_WIDTH = warpforge_pkg::WARP_ID_WIDTH,
  parameter int unsigned REG_INDEX_WIDTH = warpforge_pkg::REG_INDEX_WIDTH
) (
  input logic clk,
  input logic rst,
  input logic clear,
  input logic in_valid,
  input logic in_ready,
  input warpforge_pkg::opcode_e in_opcode,
  input logic out_valid,
  input logic out_ready,
  input logic signed [DATA_WIDTH-1:0] out_data,
  input logic [WARP_ID_WIDTH-1:0] out_warp_id,
  input logic [REG_INDEX_WIDTH-1:0] out_dst
);
  import warpforge_pkg::*;

  assert property (@(posedge clk) disable iff (rst || clear)
    in_valid && in_ready |-> opcode_is_scalar(in_opcode));

  assert property (@(posedge clk) disable iff (rst || clear)
    out_valid && !out_ready
    |=> out_valid && $stable({out_data, out_warp_id, out_dst}));

  assert property (@(posedge clk)
    rst || clear |=> !out_valid);

  assert property (@(posedge clk) disable iff (rst || clear)
    !$isunknown({in_ready, out_valid}));

endmodule
