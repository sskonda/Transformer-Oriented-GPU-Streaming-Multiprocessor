`timescale 1ns/1ps

module scheduler_tb;
  import warpforge_pkg::*;

  localparam time CLK_PERIOD = 10ns;

  logic clk = 1'b0;
  logic rst;
  logic clear;
  scheduler_policy_e policy;
  logic [NUM_WARPS-1:0] active;
  logic [NUM_WARPS-1:0] done;
  logic [NUM_WARPS-1:0] instruction_valid;
  logic [NUM_WARPS-1:0] scoreboard_stall;
  logic [NUM_WARPS-1:0] tile_wait;
  logic [NUM_WARPS-1:0] tensor_wait;
  logic [NUM_WARPS-1:0] prefetch_wait;
  logic [NUM_WARPS-1:0] tile_preferred;
  logic issue_accept;
  logic issue_valid;
  warp_id_t selected_warp_id;
  logic [NUM_WARPS-1:0] ready;
  warp_id_t round_robin_pointer;

  always #(CLK_PERIOD / 2) clk = ~clk;

  warp_scheduler dut (
    .clk,
    .rst,
    .clear,
    .policy,
    .active,
    .done,
    .instruction_valid,
    .scoreboard_stall,
    .tile_wait,
    .tensor_wait,
    .prefetch_wait,
    .tile_preferred,
    .issue_accept,
    .issue_valid,
    .selected_warp_id,
    .ready,
    .round_robin_pointer
  );

  task automatic check_issue(input warp_id_t expected);
    @(negedge clk);
    if (!issue_valid || selected_warp_id != expected) begin
      $fatal(
        1,
        "expected warp %0d, got valid=%0b warp=%0d",
        expected,
        issue_valid,
        selected_warp_id
      );
    end
  endtask

  initial begin
    rst = 1'b1;
    clear = 1'b0;
    policy = SCHED_ROUND_ROBIN;
    active = '1;
    done = '0;
    instruction_valid = '1;
    scoreboard_stall = '0;
    tile_wait = '0;
    tensor_wait = '0;
    prefetch_wait = '0;
    tile_preferred = '0;
    issue_accept = 1'b0;

    repeat (2) @(negedge clk);
    rst = 1'b0;

    check_issue(warp_id_t'(0));
    issue_accept = 1'b1;
    check_issue(warp_id_t'(1));
    check_issue(warp_id_t'(2));
    check_issue(warp_id_t'(3));
    check_issue(warp_id_t'(0));

    issue_accept = 1'b0;
    check_issue(warp_id_t'(0));
    check_issue(warp_id_t'(0));
    issue_accept = 1'b1;

    policy = SCHED_GREEDY;
    scoreboard_stall = '0;
    scoreboard_stall[0] = 1'b1;
    scoreboard_stall[2] = 1'b1;
    check_issue(warp_id_t'(1));

    policy = SCHED_MEMORY_AWARE;
    scoreboard_stall = '0;
    tile_preferred = '0;
    tile_preferred[2] = 1'b1;
    check_issue(warp_id_t'(2));

    tile_preferred = '0;
    check_issue(warp_id_t'(0));

    scoreboard_stall = '1;
    @(negedge clk);
    if (issue_valid) begin
      $fatal(1, "scheduler issued while every warp was stalled");
    end

    $display("scheduler_tb PASS");
    $finish;
  end

endmodule
