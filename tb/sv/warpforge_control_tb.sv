`timescale 1ns/1ps

module warpforge_control_tb;
  import warpforge_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam int unsigned TIMEOUT_CYCLES = 500;

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

  logic [SHARED_DATA_WIDTH-1:0] global_memory
      [0:TENSOR_TILE_WORDS-1];
  int unsigned global_request_count;

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

  task automatic apply_reset();
    rst = 1'b1;
    clear = 1'b0;
    start = 1'b0;
    load_valid = 1'b0;
    reg_load_valid = 1'b0;
    repeat (2) @(negedge clk);
    rst = 1'b0;
    @(negedge clk);
  endtask

  task automatic load_program_instruction(
    input warp_id_t warp_id,
    input instr_addr_t address,
    input opcode_e opcode,
    input reg_idx_t dst,
    input reg_idx_t src0,
    input reg_idx_t src1,
    input tile_id_t tile_id,
    input logic [15:0] immediate
  );
    load_valid = 1'b1;
    load_warp_id = warp_id;
    load_addr = address;
    load_instruction = '0;
    load_instruction.opcode = opcode;
    load_instruction.dst = dst;
    load_instruction.src0 = src0;
    load_instruction.src1 = src1;
    load_instruction.tile_id = tile_id;
    load_instruction.immediate = immediate;
    @(negedge clk);
    if (!load_ready) begin
      $fatal(1, "control test instruction load was not accepted");
    end
    load_valid = 1'b0;
  endtask

  task automatic load_register(
    input warp_id_t warp_id,
    input reg_idx_t register_index,
    input scalar_data_t data
  );
    reg_load_valid = 1'b1;
    reg_load_warp_id = warp_id;
    reg_load_reg_idx = register_index;
    reg_load_data = data;
    @(negedge clk);
    if (!reg_load_ready) begin
      $fatal(1, "control test register load was not accepted");
    end
    reg_load_valid = 1'b0;
  endtask

  task automatic start_program(input scheduler_policy_e policy);
    scheduler_policy = policy;
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;
  endtask

  task automatic check_barrier_blocks_greedy_warp();
    logic warp0_barrier_seen;
    logic warp1_barrier_seen;
    logic scalar_result_seen;
    logic completed;

    warp0_barrier_seen = 1'b0;
    warp1_barrier_seen = 1'b0;
    scalar_result_seen = 1'b0;
    completed = 1'b0;

    load_register(0, 1, 5);
    load_register(0, 2, 7);
    load_program_instruction(0, 0, OP_BARRIER, 0, 0, 0, 0, 0);
    load_program_instruction(0, 1, OP_ALU_ADD, 3, 1, 2, 0, 0);
    load_program_instruction(0, 2, OP_END, 0, 0, 0, 0, 0);
    load_program_instruction(1, 0, OP_NOP, 0, 0, 0, 0, 0);
    load_program_instruction(1, 1, OP_NOP, 0, 0, 0, 0, 0);
    load_program_instruction(1, 2, OP_BARRIER, 0, 0, 0, 0, 0);
    load_program_instruction(1, 3, OP_END, 0, 0, 0, 0, 0);
    start_program(SCHED_GREEDY);

    for (int unsigned cycle = 0; cycle < TIMEOUT_CYCLES; cycle++) begin
      @(negedge clk);
      if (issue_valid) begin
        if (
          issue_warp_id == 0 &&
          issue_instruction.opcode == OP_BARRIER
        ) begin
          warp0_barrier_seen = 1'b1;
        end
        if (
          issue_warp_id == 1 &&
          issue_instruction.opcode == OP_BARRIER
        ) begin
          warp1_barrier_seen = 1'b1;
        end
        if (
          issue_warp_id == 0 &&
          warp0_barrier_seen &&
          !warp1_barrier_seen &&
          issue_instruction.opcode != OP_BARRIER
        ) begin
          $fatal(1, "greedy warp issued past an unreleased barrier");
        end
      end

      if (
        scalar_result_valid &&
        scalar_result_warp_id == 0 &&
        scalar_result_dst == 3
      ) begin
        if (scalar_result_data != 12) begin
          $fatal(1, "post-barrier scalar result was incorrect");
        end
        scalar_result_seen = 1'b1;
      end

      if (done) begin
        completed = 1'b1;
        break;
      end
    end

    if (
      !completed ||
      !warp0_barrier_seen ||
      !warp1_barrier_seen ||
      !scalar_result_seen ||
      warp_done[1:0] != 2'b11 ||
      warp_error != '0
    ) begin
      $fatal(1, "barrier control scenario did not complete correctly");
    end
  endtask

  task automatic check_duplicate_prefetch_is_idempotent();
    int unsigned prefetch_issue_count;
    logic completed;

    prefetch_issue_count = 0;
    completed = 1'b0;

    load_program_instruction(0, 0, OP_PREFETCH_TILE, 0, 0, 0, 0, 0);
    load_program_instruction(0, 1, OP_WAIT_TILE, 0, 0, 0, 0, 0);
    load_program_instruction(0, 2, OP_PREFETCH_TILE, 0, 0, 0, 0, 0);
    load_program_instruction(0, 3, OP_END, 0, 0, 0, 0, 0);
    start_program(SCHED_ROUND_ROBIN);

    for (int unsigned cycle = 0; cycle < TIMEOUT_CYCLES; cycle++) begin
      @(negedge clk);
      if (
        issue_valid &&
        issue_warp_id == 0 &&
        issue_instruction.opcode == OP_PREFETCH_TILE
      ) begin
        prefetch_issue_count++;
      end
      if (done) begin
        completed = 1'b1;
        break;
      end
    end

    if (
      !completed ||
      prefetch_issue_count != 2 ||
      global_request_count != TENSOR_TILE_WORDS ||
      counters.prefetch_requests != 1 ||
      counters.prefetch_instructions != 1 ||
      counters.issued_instructions != 4 ||
      !tile_valid[0][0] ||
      !warp_done[0] ||
      warp_error != '0
    ) begin
      $fatal(1, "duplicate prefetch scenario did not complete idempotently");
    end
  endtask

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      global_rsp_valid <= 1'b0;
      global_rsp_data <= '0;
      global_request_count <= 0;
    end else begin
      if (global_rsp_valid && global_rsp_ready) begin
        global_rsp_valid <= 1'b0;
      end
      if (global_req_valid && global_req_ready) begin
        if (global_req_addr >= TENSOR_TILE_WORDS) begin
          $fatal(1, "control test requested an out-of-range memory word");
        end
        global_rsp_valid <= 1'b1;
        global_rsp_data <= global_memory[global_req_addr];
        global_request_count <= global_request_count + 1;
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

    for (int unsigned word = 0; word < TENSOR_TILE_WORDS; word++) begin
      global_memory[word] = SHARED_DATA_WIDTH'(word + 1);
    end

    apply_reset();
    check_barrier_blocks_greedy_warp();
    apply_reset();
    check_duplicate_prefetch_is_idempotent();

    $display("warpforge_control_tb PASS");
    $finish;
  end

  initial begin
    repeat (TIMEOUT_CYCLES * 3) @(posedge clk);
    $fatal(1, "warpforge_control_tb watchdog timeout");
  end

endmodule
