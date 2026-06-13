module perf_counters #(
  parameter int unsigned NUM_WARPS = warpforge_pkg::NUM_WARPS,
  parameter int unsigned INCREMENT_WIDTH = 8
) (
  input  logic clk,
  input  logic rst,
  input  logic clear,
  input  logic count_enable,

  input  logic event_instruction_issued,
  input  logic event_scalar_instruction,
  input  logic event_tensor_instruction,
  input  logic event_prefetch_instruction,
  input  logic event_scheduler_stall,
  input  logic event_scoreboard_stall,
  input  logic event_tile_wait,
  input  logic event_tensor_wait,
  input  logic event_prefetch_stall_cycle,
  input  logic event_tensor_busy,
  input  logic event_tensor_accepted,
  input  logic event_tensor_completed,
  input  logic [INCREMENT_WIDTH-1:0] bank_conflict_increment,
  input  logic event_prefetch_request,
  input  logic event_prefetch_stall,
  input  logic [NUM_WARPS-1:0] event_warp_completed,
  input  logic event_illegal_instruction,

  output warpforge_pkg::perf_counters_t counters
);
  import warpforge_pkg::*;

  perf_counters_t counters_r;
  logic [PERF_COUNTER_WIDTH-1:0] completed_increment;
  localparam logic [PERF_COUNTER_WIDTH-1:0] NUM_WARPS_COUNT =
      PERF_COUNTER_WIDTH'(NUM_WARPS);

  function automatic logic [PERF_COUNTER_WIDTH-1:0] saturating_add(
    input logic [PERF_COUNTER_WIDTH-1:0] value,
    input logic [PERF_COUNTER_WIDTH-1:0] increment
  );
    logic [PERF_COUNTER_WIDTH:0] sum;

    sum = {1'b0, value} + {1'b0, increment};
    return sum[PERF_COUNTER_WIDTH]
        ? {PERF_COUNTER_WIDTH{1'b1}}
        : sum[PERF_COUNTER_WIDTH-1:0];
  endfunction

  always_comb begin
    completed_increment = '0;
    for (int unsigned warp = 0; warp < NUM_WARPS; warp++) begin
      completed_increment =
          completed_increment +
          PERF_COUNTER_WIDTH'(event_warp_completed[warp]);
    end
  end

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      counters_r <= '0;
    end else begin
      if (count_enable) begin
        counters_r.total_cycles <=
            saturating_add(counters_r.total_cycles, 1);
      end
      if (event_instruction_issued) begin
        counters_r.issued_instructions <=
            saturating_add(counters_r.issued_instructions, 1);
      end
      if (event_scalar_instruction) begin
        counters_r.scalar_instructions <=
            saturating_add(counters_r.scalar_instructions, 1);
      end
      if (event_tensor_instruction) begin
        counters_r.tensor_instructions <=
            saturating_add(counters_r.tensor_instructions, 1);
      end
      if (event_prefetch_instruction) begin
        counters_r.prefetch_instructions <=
            saturating_add(counters_r.prefetch_instructions, 1);
      end
      if (event_scheduler_stall) begin
        counters_r.scheduler_stall_cycles <=
            saturating_add(counters_r.scheduler_stall_cycles, 1);
      end
      if (event_scoreboard_stall) begin
        counters_r.scoreboard_stall_cycles <=
            saturating_add(counters_r.scoreboard_stall_cycles, 1);
      end
      if (event_tile_wait) begin
        counters_r.tile_wait_cycles <=
            saturating_add(counters_r.tile_wait_cycles, 1);
      end
      if (event_tensor_wait) begin
        counters_r.tensor_wait_cycles <=
            saturating_add(counters_r.tensor_wait_cycles, 1);
      end
      if (event_prefetch_stall_cycle) begin
        counters_r.prefetch_stall_cycles <=
            saturating_add(counters_r.prefetch_stall_cycles, 1);
      end
      if (event_tensor_busy) begin
        counters_r.tensor_busy_cycles <=
            saturating_add(counters_r.tensor_busy_cycles, 1);
      end
      if (event_tensor_accepted) begin
        counters_r.tensor_accepted <=
            saturating_add(counters_r.tensor_accepted, 1);
      end
      if (event_tensor_completed) begin
        counters_r.tensor_completed <=
            saturating_add(counters_r.tensor_completed, 1);
      end
      if (bank_conflict_increment != '0) begin
        counters_r.bank_conflicts <=
            saturating_add(
              counters_r.bank_conflicts,
              PERF_COUNTER_WIDTH'(bank_conflict_increment)
            );
      end
      if (event_prefetch_request) begin
        counters_r.prefetch_requests <=
            saturating_add(counters_r.prefetch_requests, 1);
      end
      if (event_prefetch_stall) begin
        counters_r.prefetch_stalls <=
            saturating_add(counters_r.prefetch_stalls, 1);
      end
      if (completed_increment != '0) begin
        if (
          counters_r.completed_warps + completed_increment >= NUM_WARPS_COUNT
        ) begin
          counters_r.completed_warps <= NUM_WARPS_COUNT;
        end else begin
          counters_r.completed_warps <=
              counters_r.completed_warps + completed_increment;
        end
      end
      if (event_illegal_instruction) begin
        counters_r.illegal_instructions <=
            saturating_add(counters_r.illegal_instructions, 1);
      end
    end
  end

  assign counters = counters_r;

  initial begin
    if (NUM_WARPS == 0 || INCREMENT_WIDTH == 0) begin
      $fatal(1, "perf_counters parameters must be greater than zero");
    end
  end

`ifndef SYNTHESIS
  perf_counters_sva #(
    .NUM_WARPS(NUM_WARPS)
  ) assertions (
    .clk,
    .rst,
    .clear,
    .counters
  );
`endif

endmodule
