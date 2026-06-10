module instruction_queue_sva #(
  parameter int unsigned NUM_WARPS = warpforge_pkg::NUM_WARPS,
  parameter int unsigned DEPTH = warpforge_pkg::INSTR_MEM_DEPTH,
  parameter int unsigned WARP_ID_WIDTH =
      (NUM_WARPS > 1) ? $clog2(NUM_WARPS) : 1,
  parameter int unsigned ADDR_WIDTH =
      (DEPTH > 1) ? $clog2(DEPTH) : 1
) (
  input logic clk,
  input logic rst,
  input logic clear,
  input logic load_valid,
  input logic load_ready,
  input logic [WARP_ID_WIDTH-1:0] load_warp_id,
  input logic [ADDR_WIDTH-1:0] load_addr,
  input logic issue_valid,
  input logic issue_accept,
  input logic [WARP_ID_WIDTH-1:0] issue_warp_id,
  input logic [NUM_WARPS-1:0] instruction_valid,
  input logic [NUM_WARPS-1:0] current_end,
  input logic [NUM_WARPS-1:0] current_illegal,
  input wire logic [NUM_WARPS-1:0][ADDR_WIDTH-1:0] pc,
  input logic [NUM_WARPS-1:0] end_issued,
  input logic [NUM_WARPS-1:0] illegal_issued
);

  assert property (@(posedge clk) disable iff (rst || clear)
    load_valid && load_ready |-> load_warp_id < NUM_WARPS &&
                                load_addr < DEPTH);

  assert property (@(posedge clk) disable iff (rst || clear)
    issue_valid && issue_accept |-> issue_warp_id < NUM_WARPS &&
                                   instruction_valid[issue_warp_id]);

  generate
    for (genvar warp = 0; warp < NUM_WARPS; warp++) begin : g_pc_checks
      assert property (@(posedge clk)
        pc[warp] < DEPTH);

      assert property (@(posedge clk) disable iff (rst || clear)
        $changed(pc[warp]) |->
          $past(
            issue_valid &&
            issue_accept &&
            issue_warp_id == warp &&
            !current_end[warp] &&
            !current_illegal[warp]
          ));

      assert property (@(posedge clk) disable iff (rst || clear)
        issue_valid &&
        issue_accept &&
        issue_warp_id == warp &&
        current_end[warp]
        |=> end_issued[warp] && !instruction_valid[warp]);

      assert property (@(posedge clk) disable iff (rst || clear)
        issue_valid &&
        issue_accept &&
        issue_warp_id == warp &&
        current_illegal[warp]
        |=> illegal_issued[warp] && !instruction_valid[warp]);
    end
  endgenerate

endmodule
