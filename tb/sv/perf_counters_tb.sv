`timescale 1ns/1ps

module perf_counters_tb;
  import warpforge_pkg::*;

  localparam time CLK_PERIOD = 10ns;

  logic clk = 1'b0;
  logic rst;
  logic clear;
  logic count_enable;
  logic event_instruction_issued;
  logic event_scalar_instruction;
  logic event_tensor_instruction;
  logic event_prefetch_instruction;
  logic event_scheduler_stall;
  logic event_scoreboard_stall;
  logic event_tile_wait;
  logic event_tensor_wait;
  logic event_prefetch_stall_cycle;
  logic event_tensor_busy;
  logic event_tensor_accepted;
  logic event_tensor_completed;
  logic [7:0] bank_conflict_increment;
  logic event_prefetch_request;
  logic event_prefetch_stall;
  logic [NUM_WARPS-1:0] event_warp_completed;
  logic event_illegal_instruction;
  perf_counters_t counters;

  always #(CLK_PERIOD / 2) clk = ~clk;

  perf_counters dut (
    .clk,
    .rst,
    .clear,
    .count_enable,
    .event_instruction_issued,
    .event_scalar_instruction,
    .event_tensor_instruction,
    .event_prefetch_instruction,
    .event_scheduler_stall,
    .event_scoreboard_stall,
    .event_tile_wait,
    .event_tensor_wait,
    .event_prefetch_stall_cycle,
    .event_tensor_busy,
    .event_tensor_accepted,
    .event_tensor_completed,
    .bank_conflict_increment,
    .event_prefetch_request,
    .event_prefetch_stall,
    .event_warp_completed,
    .event_illegal_instruction,
    .counters
  );

  task automatic clear_events();
    event_instruction_issued = 1'b0;
    event_scalar_instruction = 1'b0;
    event_tensor_instruction = 1'b0;
    event_prefetch_instruction = 1'b0;
    event_scheduler_stall = 1'b0;
    event_scoreboard_stall = 1'b0;
    event_tile_wait = 1'b0;
    event_tensor_wait = 1'b0;
    event_prefetch_stall_cycle = 1'b0;
    event_tensor_busy = 1'b0;
    event_tensor_accepted = 1'b0;
    event_tensor_completed = 1'b0;
    bank_conflict_increment = '0;
    event_prefetch_request = 1'b0;
    event_prefetch_stall = 1'b0;
    event_warp_completed = '0;
    event_illegal_instruction = 1'b0;
  endtask

  initial begin
    rst = 1'b1;
    clear = 1'b0;
    count_enable = 1'b0;
    clear_events();

    repeat (2) @(negedge clk);
    rst = 1'b0;
    count_enable = 1'b1;
    repeat (5) @(posedge clk);
    @(negedge clk);
    count_enable = 1'b0;

    if (counters.total_cycles != 5) begin
      $fatal(1, "total cycle count mismatch");
    end

    event_instruction_issued = 1'b1;
    event_scalar_instruction = 1'b1;
    event_tensor_instruction = 1'b1;
    event_prefetch_instruction = 1'b1;
    event_scheduler_stall = 1'b1;
    event_scoreboard_stall = 1'b1;
    event_tile_wait = 1'b1;
    event_tensor_wait = 1'b1;
    event_prefetch_stall_cycle = 1'b1;
    event_tensor_busy = 1'b1;
    event_tensor_accepted = 1'b1;
    event_tensor_completed = 1'b1;
    bank_conflict_increment = 2;
    event_prefetch_request = 1'b1;
    event_prefetch_stall = 1'b1;
    event_warp_completed = 4'b0011;
    event_illegal_instruction = 1'b1;
    @(posedge clk);
    @(negedge clk);
    clear_events();

    if (
      counters.issued_instructions != 1 ||
      counters.scalar_instructions != 1 ||
      counters.tensor_instructions != 1 ||
      counters.prefetch_instructions != 1 ||
      counters.scheduler_stall_cycles != 1 ||
      counters.scoreboard_stall_cycles != 1 ||
      counters.tile_wait_cycles != 1 ||
      counters.tensor_wait_cycles != 1 ||
      counters.prefetch_stall_cycles != 1 ||
      counters.tensor_busy_cycles != 1 ||
      counters.tensor_accepted != 1 ||
      counters.tensor_completed != 1 ||
      counters.bank_conflicts != 2 ||
      counters.prefetch_requests != 1 ||
      counters.prefetch_stalls != 1 ||
      counters.completed_warps != 2 ||
      counters.illegal_instructions != 1
    ) begin
      $fatal(1, "event counter update mismatch");
    end

    event_warp_completed = '1;
    @(posedge clk);
    @(negedge clk);
    clear_events();
    if (counters.completed_warps != PERF_COUNTER_WIDTH'(NUM_WARPS)) begin
      $fatal(1, "completed warp count did not saturate");
    end

    clear = 1'b1;
    @(posedge clk);
    @(negedge clk);
    clear = 1'b0;
    if (counters != '0) begin
      $fatal(1, "clear did not reset counters");
    end

    $display("perf_counters_tb PASS");
    $finish;
  end

endmodule
