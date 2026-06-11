module scoreboard_sva #(
  parameter int unsigned NUM_WARPS = warpforge_pkg::NUM_WARPS,
  parameter int unsigned NUM_REGS = warpforge_pkg::NUM_REGS,
  parameter int unsigned WARP_ID_WIDTH =
      (NUM_WARPS > 1) ? $clog2(NUM_WARPS) : 1,
  parameter int unsigned REG_INDEX_WIDTH =
      (NUM_REGS > 1) ? $clog2(NUM_REGS) : 1
) (
  input logic clk,
  input logic rst,
  input logic clear,
  input logic set_valid,
  input logic [WARP_ID_WIDTH-1:0] set_warp_id,
  input logic [REG_INDEX_WIDTH-1:0] set_reg_idx,
  input logic clear_valid,
  input logic [WARP_ID_WIDTH-1:0] clear_warp_id,
  input logic [REG_INDEX_WIDTH-1:0] clear_reg_idx,
  input logic [NUM_WARPS-1:0] stall,
  input wire logic [NUM_WARPS-1:0][NUM_REGS-1:0] busy
);

  assert property (@(posedge clk)
    rst || clear |=> busy == '0);

  assert property (@(posedge clk) disable iff (rst || clear)
    !$isunknown(stall));

  assert property (@(posedge clk) disable iff (rst || clear)
    set_valid |-> set_warp_id < NUM_WARPS && set_reg_idx < NUM_REGS);

  assert property (@(posedge clk) disable iff (rst || clear)
    clear_valid |-> clear_warp_id < NUM_WARPS && clear_reg_idx < NUM_REGS);

  assert property (@(posedge clk) disable iff (rst || clear)
    set_valid && clear_valid &&
    set_warp_id == clear_warp_id &&
    set_reg_idx == clear_reg_idx
    |=> !busy[$past(clear_warp_id)][$past(clear_reg_idx)]);

endmodule
