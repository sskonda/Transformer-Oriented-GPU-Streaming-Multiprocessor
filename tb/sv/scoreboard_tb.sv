`timescale 1ns/1ps

module scoreboard_tb;
  import warpforge_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam warp_id_t TEST_WARP = warp_id_t'(0);
  localparam reg_idx_t TEST_REG = reg_idx_t'(3);
  localparam reg_idx_t OTHER_REG = reg_idx_t'(7);

  logic clk = 1'b0;
  logic rst;
  logic clear;
  logic set_valid;
  warp_id_t set_warp_id;
  reg_idx_t set_reg_idx;
  logic clear_valid;
  warp_id_t clear_warp_id;
  reg_idx_t clear_reg_idx;
  logic [NUM_WARPS-1:0] query_use_src0;
  logic [NUM_WARPS-1:0] query_use_src1;
  logic [NUM_WARPS-1:0] query_use_src2;
  logic [NUM_WARPS-1:0][REG_INDEX_WIDTH-1:0] query_src0;
  logic [NUM_WARPS-1:0][REG_INDEX_WIDTH-1:0] query_src1;
  logic [NUM_WARPS-1:0][REG_INDEX_WIDTH-1:0] query_src2;
  logic [NUM_WARPS-1:0] stall;
  logic [NUM_WARPS-1:0][NUM_REGS-1:0] busy;

  always #(CLK_PERIOD / 2) clk = ~clk;

  scoreboard dut (
    .clk,
    .rst,
    .clear,
    .set_valid,
    .set_warp_id,
    .set_reg_idx,
    .clear_valid,
    .clear_warp_id,
    .clear_reg_idx,
    .query_use_src0,
    .query_use_src1,
    .query_use_src2,
    .query_src0,
    .query_src1,
    .query_src2,
    .stall,
    .busy
  );

  task automatic drive_idle();
    set_valid = 1'b0;
    clear_valid = 1'b0;
  endtask

  task automatic check(input logic condition, input string message);
    if (!condition) begin
      $fatal(1, "%s", message);
    end
  endtask

  initial begin
    rst = 1'b1;
    clear = 1'b0;
    drive_idle();
    set_warp_id = '0;
    set_reg_idx = '0;
    clear_warp_id = '0;
    clear_reg_idx = '0;
    query_use_src0 = '0;
    query_use_src1 = '0;
    query_use_src2 = '0;
    query_src0 = '0;
    query_src1 = '0;
    query_src2 = '0;

    repeat (2) @(negedge clk);
    rst = 1'b0;

    query_use_src0[TEST_WARP] = 1'b1;
    query_src0[TEST_WARP] = TEST_REG;
    set_valid = 1'b1;
    set_warp_id = TEST_WARP;
    set_reg_idx = TEST_REG;
    @(negedge clk);
    drive_idle();
    check(busy[TEST_WARP][TEST_REG], "set did not mark register busy");
    check(stall[TEST_WARP], "busy source did not stall warp");

    clear_valid = 1'b1;
    clear_warp_id = TEST_WARP;
    clear_reg_idx = TEST_REG;
    @(negedge clk);
    drive_idle();
    check(!busy[TEST_WARP][TEST_REG], "clear did not release register");
    check(!stall[TEST_WARP], "released source still stalled warp");

    set_valid = 1'b1;
    set_warp_id = TEST_WARP;
    set_reg_idx = OTHER_REG;
    @(negedge clk);
    drive_idle();
    check(busy[TEST_WARP][OTHER_REG], "unrelated register was not set");

    set_valid = 1'b1;
    set_warp_id = TEST_WARP;
    set_reg_idx = TEST_REG;
    clear_valid = 1'b1;
    clear_warp_id = TEST_WARP;
    clear_reg_idx = TEST_REG;
    @(negedge clk);
    drive_idle();
    check(!busy[TEST_WARP][TEST_REG], "simultaneous set/clear was not clear-wins");
    check(busy[TEST_WARP][OTHER_REG], "simultaneous event changed unrelated state");

    $display("scoreboard_tb PASS");
    $finish;
  end

endmodule
