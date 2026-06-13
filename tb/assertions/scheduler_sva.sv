module scheduler_sva #(
  parameter int unsigned NUM_WARPS = warpforge_pkg::NUM_WARPS,
  parameter int unsigned WARP_ID_WIDTH =
      (NUM_WARPS > 1) ? $clog2(NUM_WARPS) : 1
) (
  input logic clk,
  input logic rst,
  input logic clear,
  input warpforge_pkg::scheduler_policy_e policy,
  input logic [NUM_WARPS-1:0] active,
  input logic [NUM_WARPS-1:0] done,
  input logic [NUM_WARPS-1:0] scoreboard_stall,
  input logic [NUM_WARPS-1:0] tile_wait,
  input logic [NUM_WARPS-1:0] tensor_wait,
  input logic [NUM_WARPS-1:0] prefetch_wait,
  input logic [NUM_WARPS-1:0] barrier_wait,
  input logic issue_valid,
  input logic [WARP_ID_WIDTH-1:0] selected_warp_id,
  input logic [NUM_WARPS-1:0] ready,
  input logic [WARP_ID_WIDTH-1:0] round_robin_pointer
);
  import warpforge_pkg::*;

  assert property (@(posedge clk) rst || clear |-> !issue_valid);

  assert property (@(posedge clk) disable iff (rst || clear)
    issue_valid |-> selected_warp_id < NUM_WARPS);

  assert property (@(posedge clk) disable iff (rst || clear)
    issue_valid |-> ready[selected_warp_id]);

  assert property (@(posedge clk) disable iff (rst || clear)
    issue_valid |-> active[selected_warp_id] && !done[selected_warp_id]);

  assert property (@(posedge clk) disable iff (rst || clear)
    issue_valid |-> !scoreboard_stall[selected_warp_id] &&
                    !tile_wait[selected_warp_id] &&
                    !tensor_wait[selected_warp_id] &&
                    !prefetch_wait[selected_warp_id] &&
                    !barrier_wait[selected_warp_id]);

  assert property (@(posedge clk)
    round_robin_pointer < NUM_WARPS);

  assert property (@(posedge clk)
    policy == SCHED_ROUND_ROBIN ||
    policy == SCHED_GREEDY ||
    policy == SCHED_MEMORY_AWARE);

endmodule
