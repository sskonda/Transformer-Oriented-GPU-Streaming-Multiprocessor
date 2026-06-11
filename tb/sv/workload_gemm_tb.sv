`timescale 1ns/1ps

module workload_gemm_tb;
  import warpforge_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam int unsigned PROGRAM_LENGTH = 4;
  localparam int unsigned RESULT_ELEMENTS = TENSOR_M * TENSOR_N;
  localparam int unsigned TIMEOUT_CYCLES = 300;
  localparam int unsigned WORKLOAD_SEED = 17;

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

  logic [$bits(instruction_t)-1:0] program_memory
      [0:PROGRAM_LENGTH-1];
  logic [SHARED_DATA_WIDTH-1:0] global_memory
      [0:TENSOR_TILE_WORDS-1];
  logic signed [TENSOR_ACC_WIDTH-1:0] expected_result
      [0:RESULT_ELEMENTS-1];
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

  task automatic load_program();
    for (
      int unsigned address = 0;
      address < PROGRAM_LENGTH;
      address++
    ) begin
      @(negedge clk);
      load_valid = 1'b1;
      load_warp_id = '0;
      load_addr = instr_addr_t'(address);
      load_instruction = instruction_t'(program_memory[address]);
      @(negedge clk);
      if (!load_ready) begin
        $fatal(1, "GEMM instruction load was not accepted");
      end
      load_valid = 1'b0;
    end
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
        if (global_req_addr >= TENSOR_TILE_WORDS) begin
          $fatal(1, "GEMM requested an out-of-range memory word");
        end
        global_rsp_valid <= 1'b1;
        global_rsp_data <= global_memory[global_req_addr];
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      saw_tensor_result <= 1'b0;
    end else if (tensor_result_valid) begin
      if (tensor_result_warp_id != 0 || tensor_result_dst != 0) begin
        $fatal(1, "GEMM tensor result metadata was incorrect");
      end
      for (int unsigned row = 0; row < TENSOR_M; row++) begin
        for (int unsigned column = 0; column < TENSOR_N; column++) begin
          if (
            tensor_result[row][column] !=
            expected_result[(row * TENSOR_N) + column]
          ) begin
            $fatal(
              1,
              "GEMM mismatch at [%0d][%0d]: expected %0d, got %0d",
              row,
              column,
              expected_result[(row * TENSOR_N) + column],
              tensor_result[row][column]
            );
          end
        end
      end
      saw_tensor_result <= 1'b1;
    end
  end

  initial begin
    $readmemh("../../workloads/gemm/program.hex", program_memory);
    $readmemh("../../workloads/gemm/memory.hex", global_memory);
    $readmemh("../../workloads/gemm/result.hex", expected_result);

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

    repeat (2) @(negedge clk);
    rst = 1'b0;
    load_program();

    @(negedge clk);
    start = 1'b1;
    @(negedge clk);
    start = 1'b0;

    for (int unsigned cycle = 0; cycle < TIMEOUT_CYCLES; cycle++) begin
      @(negedge clk);
      if (done) begin
        if (
          !warp_done[0] ||
          warp_error != '0 ||
          !saw_tensor_result ||
          counters.completed_warps != 1 ||
          counters.tensor_completed != 1 ||
          counters.prefetch_requests != 1
        ) begin
          $fatal(1, "GEMM completion state was incorrect");
        end
        $display(
          "%s",
          $sformatf(
            {
              "WARPFORGE_PERF workload=gemm policy=SCHED_ROUND_ROBIN ",
              "seed=%0d cycles=%0d issued=%0d scalar=%0d tensor=%0d ",
              "prefetch=%0d scheduler_stall=%0d scoreboard_stall=%0d ",
              "tile_wait=%0d tensor_wait=%0d prefetch_stall=%0d ",
              "tensor_busy=%0d tensor_accepted=%0d tensor_completed=%0d ",
              "bank_conflicts=%0d prefetch_requests=%0d ",
              "prefetch_stalls=%0d completed_warps=%0d illegal=%0d"
            },
            WORKLOAD_SEED,
            counters.total_cycles,
            counters.issued_instructions,
            counters.scalar_instructions,
            counters.tensor_instructions,
            counters.prefetch_instructions,
            counters.scheduler_stall_cycles,
            counters.scoreboard_stall_cycles,
            counters.tile_wait_cycles,
            counters.tensor_wait_cycles,
            counters.prefetch_stall_cycles,
            counters.tensor_busy_cycles,
            counters.tensor_accepted,
            counters.tensor_completed,
            counters.bank_conflicts,
            counters.prefetch_requests,
            counters.prefetch_stalls,
            counters.completed_warps,
            counters.illegal_instructions
          )
        );
        $display("workload_gemm_tb PASS");
        $finish;
      end
    end

    $fatal(1, "GEMM workload timed out");
  end

endmodule
