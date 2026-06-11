`timescale 1ns/1ps

module warpforge_top_tb;
  import warpforge_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam int unsigned TIMEOUT_CYCLES = 300;

  logic clk = 1'b0;
  logic rst;
  logic clear;
  logic start;
  scheduler_policy_e scheduler_policy;
  logic load_valid;
  logic load_ready;
  warp_id_t load_warp_id;
  instr_addr_t load_addr;
  instruction_t load_instruction;
  logic reg_load_valid;
  logic reg_load_ready;
  warp_id_t reg_load_warp_id;
  reg_idx_t reg_load_reg_idx;
  scalar_data_t reg_load_data;
  logic global_req_valid;
  logic global_req_ready;
  logic [GLOBAL_ADDR_WIDTH-1:0] global_req_addr;
  logic global_rsp_valid;
  logic global_rsp_ready;
  logic [SHARED_DATA_WIDTH-1:0] global_rsp_data;
  logic busy;
  logic done;
  logic issue_valid;
  warp_id_t issue_warp_id;
  instruction_t issue_instruction;
  logic [NUM_WARPS-1:0] warp_done;
  logic [NUM_WARPS-1:0] warp_error;
  logic scalar_result_valid;
  warp_id_t scalar_result_warp_id;
  reg_idx_t scalar_result_dst;
  scalar_data_t scalar_result_data;
  logic tensor_result_valid;
  warp_id_t tensor_result_warp_id;
  reg_idx_t tensor_result_dst;
  logic signed [TENSOR_M-1:0][TENSOR_N-1:0]
      [TENSOR_ACC_WIDTH-1:0] tensor_result;
  logic [NUM_WARPS-1:0][NUM_TILES-1:0] tile_valid;
  perf_counters_t counters;
  logic [SHARED_DATA_WIDTH-1:0] global_memory [0:TENSOR_TILE_WORDS-1];
  logic saw_scalar_result;
  logic saw_tensor_result;

  always #(CLK_PERIOD / 2) clk = ~clk;

  warpforge_top dut (
    .clk,
    .rst,
    .clear,
    .start,
    .scheduler_policy,
    .load_valid,
    .load_ready,
    .load_warp_id,
    .load_addr,
    .load_instruction,
    .reg_load_valid,
    .reg_load_ready,
    .reg_load_warp_id,
    .reg_load_reg_idx,
    .reg_load_data,
    .global_req_valid,
    .global_req_ready,
    .global_req_addr,
    .global_rsp_valid,
    .global_rsp_ready,
    .global_rsp_data,
    .busy,
    .done,
    .issue_valid,
    .issue_warp_id,
    .issue_instruction,
    .warp_done,
    .warp_error,
    .scalar_result_valid,
    .scalar_result_warp_id,
    .scalar_result_dst,
    .scalar_result_data,
    .tensor_result_valid,
    .tensor_result_warp_id,
    .tensor_result_dst,
    .tensor_result,
    .tile_valid,
    .counters
  );

  task automatic load_program_instruction(
    input warp_id_t warp_id,
    input instr_addr_t address,
    input opcode_e opcode,
    input reg_idx_t dst,
    input reg_idx_t src0,
    input reg_idx_t src1,
    input reg_idx_t src2,
    input tile_id_t tile_id,
    input logic [15:0] immediate
  );
    @(negedge clk);
    load_valid = 1'b1;
    load_warp_id = warp_id;
    load_addr = address;
    load_instruction = '0;
    load_instruction.opcode = opcode;
    load_instruction.dst = dst;
    load_instruction.src0 = src0;
    load_instruction.src1 = src1;
    load_instruction.src2 = src2;
    load_instruction.tile_id = tile_id;
    load_instruction.immediate = immediate;
    @(negedge clk);
    if (!load_ready) begin
      $fatal(1, "instruction load was not accepted");
    end
    load_valid = 1'b0;
  endtask

  task automatic load_register(
    input warp_id_t warp_id,
    input reg_idx_t reg_index,
    input scalar_data_t data
  );
    @(negedge clk);
    reg_load_valid = 1'b1;
    reg_load_warp_id = warp_id;
    reg_load_reg_idx = reg_index;
    reg_load_data = data;
    @(negedge clk);
    if (!reg_load_ready) begin
      $fatal(1, "register load was not accepted");
    end
    reg_load_valid = 1'b0;
  endtask

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      global_rsp_valid <= 1'b0;
      global_rsp_data <= '0;
    end else begin
      if (global_rsp_valid && global_rsp_ready) begin
        global_rsp_valid <= 1'b0;
      end
      if (global_req_valid && global_req_ready) begin
        global_rsp_valid <= 1'b1;
        global_rsp_data <= global_memory[global_req_addr];
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      saw_scalar_result <= 1'b0;
      saw_tensor_result <= 1'b0;
    end else begin
      if (
        scalar_result_valid &&
        scalar_result_warp_id == 1 &&
        scalar_result_dst == 5
      ) begin
        if (scalar_result_data != 19) begin
          $fatal(1, "dependent scalar result was incorrect");
        end
        saw_scalar_result <= 1'b1;
      end

      if (tensor_result_valid) begin
        if (
          tensor_result_warp_id != 0 ||
          tensor_result_dst != 0
        ) begin
          $fatal(1, "tensor result or metadata was incorrect");
        end
        for (int unsigned row = 0; row < TENSOR_M; row++) begin
          for (int unsigned col = 0; col < TENSOR_N; col++) begin
            if (tensor_result[row][col] != (row * TENSOR_N) + col + 1) begin
              $fatal(
                1,
                "tensor result mismatch at [%0d][%0d]",
                row,
                col
              );
            end
          end
        end
        saw_tensor_result <= 1'b1;
      end
    end
  end

  initial begin
    rst = 1'b1;
    clear = 1'b0;
    start = 1'b0;
    scheduler_policy = SCHED_ROUND_ROBIN;
    load_valid = 1'b0;
    load_warp_id = '0;
    load_addr = '0;
    load_instruction = '0;
    reg_load_valid = 1'b0;
    reg_load_warp_id = '0;
    reg_load_reg_idx = '0;
    reg_load_data = '0;
    global_req_ready = 1'b1;

    global_memory[0] = 32'h0403_0201;
    global_memory[1] = 32'h0807_0605;
    global_memory[2] = 32'h0c0b_0a09;
    global_memory[3] = 32'h100f_0e0d;
    global_memory[4] = 32'h0000_0001;
    global_memory[5] = 32'h0000_0100;
    global_memory[6] = 32'h0001_0000;
    global_memory[7] = 32'h0100_0000;

    repeat (2) @(negedge clk);
    rst = 1'b0;

    load_program_instruction(0, 0, OP_PREFETCH_TILE, 0, 0, 0, 0, 0, 0);
    load_program_instruction(0, 1, OP_WAIT_TILE, 0, 0, 0, 0, 0, 0);
    load_program_instruction(0, 2, OP_TENSOR_MMA, 0, 0, 0, 0, 0, 0);
    load_program_instruction(0, 3, OP_END, 0, 0, 0, 0, 0, 0);

    load_register(1, 1, 2);
    load_register(1, 2, 3);
    load_register(1, 3, 4);
    load_program_instruction(1, 0, OP_ALU_ADD, 4, 1, 2, 0, 0, 0);
    load_program_instruction(1, 1, OP_ALU_MAD, 5, 4, 2, 3, 0, 0);
    load_program_instruction(1, 2, OP_END, 0, 0, 0, 0, 0, 0);

    @(negedge clk);
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;

    for (int unsigned cycle = 0; cycle < TIMEOUT_CYCLES; cycle++) begin
      @(negedge clk);
      if (done) begin
        if (
          warp_done[1:0] != 2'b11 ||
          warp_error != '0 ||
          !saw_scalar_result ||
          !saw_tensor_result ||
          counters.completed_warps != 2 ||
          counters.tensor_completed != 1 ||
          counters.prefetch_requests != 1
        ) begin
          $fatal(1, "top-level completion state was incorrect");
        end
        $display("warpforge_top_tb PASS");
        $finish;
      end
    end

    $fatal(1, "top-level smoke test timed out");
  end

endmodule
