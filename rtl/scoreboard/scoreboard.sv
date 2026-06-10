module scoreboard #(
  parameter int unsigned NUM_WARPS = warpforge_pkg::NUM_WARPS,
  parameter int unsigned NUM_REGS = warpforge_pkg::NUM_REGS,
  parameter int unsigned WARP_ID_WIDTH =
      (NUM_WARPS > 1) ? $clog2(NUM_WARPS) : 1,
  parameter int unsigned REG_INDEX_WIDTH =
      (NUM_REGS > 1) ? $clog2(NUM_REGS) : 1
) (
  input  logic clk,
  input  logic rst,
  input  logic clear,

  input  logic set_valid,
  input  logic [WARP_ID_WIDTH-1:0] set_warp_id,
  input  logic [REG_INDEX_WIDTH-1:0] set_reg_idx,

  input  logic clear_valid,
  input  logic [WARP_ID_WIDTH-1:0] clear_warp_id,
  input  logic [REG_INDEX_WIDTH-1:0] clear_reg_idx,

  input  logic [NUM_WARPS-1:0] query_use_src0,
  input  logic [NUM_WARPS-1:0] query_use_src1,
  input  logic [NUM_WARPS-1:0] query_use_src2,
  input  wire logic [NUM_WARPS-1:0][REG_INDEX_WIDTH-1:0] query_src0,
  input  wire logic [NUM_WARPS-1:0][REG_INDEX_WIDTH-1:0] query_src1,
  input  wire logic [NUM_WARPS-1:0][REG_INDEX_WIDTH-1:0] query_src2,

  output logic [NUM_WARPS-1:0] stall,
  output logic [NUM_WARPS-1:0][NUM_REGS-1:0] busy
);

  logic [NUM_WARPS-1:0][NUM_REGS-1:0] busy_r;

  always_comb begin
    for (int unsigned warp = 0; warp < NUM_WARPS; warp++) begin
      stall[warp] =
          (query_use_src0[warp] && busy_r[warp][query_src0[warp]]) ||
          (query_use_src1[warp] && busy_r[warp][query_src1[warp]]) ||
          (query_use_src2[warp] && busy_r[warp][query_src2[warp]]);
    end
  end

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      busy_r <= '0;
    end else begin
      if (set_valid) begin
        busy_r[set_warp_id][set_reg_idx] <= 1'b1;
      end

      if (clear_valid) begin
        busy_r[clear_warp_id][clear_reg_idx] <= 1'b0;
      end
    end
  end

  assign busy = busy_r;

  initial begin
    if (NUM_WARPS == 0 || NUM_REGS == 0) begin
      $fatal(1, "scoreboard dimensions must be greater than zero");
    end
  end

`ifndef SYNTHESIS
  scoreboard_sva #(
    .NUM_WARPS(NUM_WARPS),
    .NUM_REGS(NUM_REGS),
    .WARP_ID_WIDTH(WARP_ID_WIDTH),
    .REG_INDEX_WIDTH(REG_INDEX_WIDTH)
  ) assertions (
    .clk,
    .rst,
    .clear,
    .set_valid,
    .set_warp_id,
    .set_reg_idx,
    .clear_valid,
    .clear_warp_id,
    .clear_reg_idx,
    .stall,
    .busy
  );
`endif

endmodule
