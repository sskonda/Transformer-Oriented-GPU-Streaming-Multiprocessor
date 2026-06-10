module perf_counters_sva #(
  parameter int unsigned NUM_WARPS = warpforge_pkg::NUM_WARPS
) (
  input logic clk,
  input logic rst,
  input logic clear,
  input wire warpforge_pkg::perf_counters_t counters
);

  assert property (@(posedge clk)
    rst || clear |=> counters == '0);

  assert property (@(posedge clk) disable iff (rst || clear)
    !$isunknown(counters));

  assert property (@(posedge clk) disable iff (rst || clear)
    counters.total_cycles >= $past(counters.total_cycles));
  assert property (@(posedge clk) disable iff (rst || clear)
    counters.issued_instructions >= $past(counters.issued_instructions));
  assert property (@(posedge clk) disable iff (rst || clear)
    counters.scalar_instructions >= $past(counters.scalar_instructions));
  assert property (@(posedge clk) disable iff (rst || clear)
    counters.tensor_instructions >= $past(counters.tensor_instructions));
  assert property (@(posedge clk) disable iff (rst || clear)
    counters.prefetch_instructions >= $past(counters.prefetch_instructions));
  assert property (@(posedge clk) disable iff (rst || clear)
    counters.scheduler_stall_cycles >=
      $past(counters.scheduler_stall_cycles));
  assert property (@(posedge clk) disable iff (rst || clear)
    counters.scoreboard_stall_cycles >=
      $past(counters.scoreboard_stall_cycles));
  assert property (@(posedge clk) disable iff (rst || clear)
    counters.tile_wait_cycles >= $past(counters.tile_wait_cycles));
  assert property (@(posedge clk) disable iff (rst || clear)
    counters.tensor_wait_cycles >= $past(counters.tensor_wait_cycles));
  assert property (@(posedge clk) disable iff (rst || clear)
    counters.prefetch_stall_cycles >=
      $past(counters.prefetch_stall_cycles));
  assert property (@(posedge clk) disable iff (rst || clear)
    counters.tensor_busy_cycles >= $past(counters.tensor_busy_cycles));
  assert property (@(posedge clk) disable iff (rst || clear)
    counters.tensor_accepted >= $past(counters.tensor_accepted));
  assert property (@(posedge clk) disable iff (rst || clear)
    counters.tensor_completed >= $past(counters.tensor_completed));
  assert property (@(posedge clk) disable iff (rst || clear)
    counters.bank_conflicts >= $past(counters.bank_conflicts));
  assert property (@(posedge clk) disable iff (rst || clear)
    counters.prefetch_requests >= $past(counters.prefetch_requests));
  assert property (@(posedge clk) disable iff (rst || clear)
    counters.prefetch_stalls >= $past(counters.prefetch_stalls));
  assert property (@(posedge clk) disable iff (rst || clear)
    counters.completed_warps >= $past(counters.completed_warps));
  assert property (@(posedge clk) disable iff (rst || clear)
    counters.illegal_instructions >=
      $past(counters.illegal_instructions));

  assert property (@(posedge clk)
    counters.completed_warps <= NUM_WARPS);

endmodule
