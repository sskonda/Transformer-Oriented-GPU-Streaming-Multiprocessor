`timescale 1ns/1ps
`include "uvm_macros.svh"

module tb_top;
  import uvm_pkg::*;
  import warpforge_pkg::*;
  import warpforge_uvm_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam int unsigned WATCHDOG_CYCLES = 2000;

  logic clk = 1'b0;
  warpforge_if vif(clk);

  always #(CLK_PERIOD / 2) clk = ~clk;

  warpforge_top dut (
    .clk,
    .rst(vif.rst),
    .clear(vif.clear),
    .start(vif.start),
    .scheduler_policy(vif.scheduler_policy),
    .load_valid(vif.load_valid),
    .load_ready(vif.load_ready),
    .load_warp_id(vif.load_warp_id),
    .load_addr(vif.load_addr),
    .load_instruction(vif.load_instruction),
    .reg_load_valid(vif.reg_load_valid),
    .reg_load_ready(vif.reg_load_ready),
    .reg_load_warp_id(vif.reg_load_warp_id),
    .reg_load_reg_idx(vif.reg_load_reg_idx),
    .reg_load_data(vif.reg_load_data),
    .global_req_valid(vif.global_req_valid),
    .global_req_ready(vif.global_req_ready),
    .global_req_addr(vif.global_req_addr),
    .global_rsp_valid(vif.global_rsp_valid),
    .global_rsp_ready(vif.global_rsp_ready),
    .global_rsp_data(vif.global_rsp_data),
    .busy(vif.busy),
    .done(vif.done),
    .issue_valid(vif.issue_valid),
    .issue_warp_id(vif.issue_warp_id),
    .issue_instruction(vif.issue_instruction),
    .warp_done(vif.warp_done),
    .warp_error(vif.warp_error),
    .scalar_result_valid(vif.scalar_result_valid),
    .scalar_result_warp_id(vif.scalar_result_warp_id),
    .scalar_result_dst(vif.scalar_result_dst),
    .scalar_result_data(vif.scalar_result_data),
    .tensor_result_valid(vif.tensor_result_valid),
    .tensor_result_warp_id(vif.tensor_result_warp_id),
    .tensor_result_dst(vif.tensor_result_dst),
    .tensor_result(vif.tensor_result),
    .tile_valid(vif.tile_valid),
    .counters(vif.counters)
  );

  initial begin
    uvm_config_db#(virtual warpforge_if)::set(null, "*", "vif", vif);
    run_test();
  end

  initial begin
    repeat (WATCHDOG_CYCLES) @(posedge clk);
    `uvm_fatal("WATCHDOG", "Global UVM timeout expired")
  end
endmodule
