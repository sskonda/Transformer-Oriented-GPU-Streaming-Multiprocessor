module top_sva #(
  parameter int unsigned NUM_WARPS = warpforge_pkg::NUM_WARPS
) (
  input logic clk,
  input logic rst,
  input logic clear,
  input logic issue_fire,
  input logic issue_accept,
  input warpforge_pkg::warp_id_t issue_warp_id,
  input wire warpforge_pkg::instruction_t issue_instruction,
  input logic [NUM_WARPS-1:0] warp_active,
  input logic [NUM_WARPS-1:0] warp_done,
  input logic [NUM_WARPS-1:0] warp_error,
  input logic [NUM_WARPS-1:0] launch_mask,
  input logic busy,
  input logic done,
  input wire warpforge_pkg::perf_counters_t counters
);
  import warpforge_pkg::*;

  assert property (@(posedge clk)
    rst || clear |-> !issue_fire);

  assert property (@(posedge clk) disable iff (rst || clear)
    issue_fire |-> issue_accept);

  assert property (@(posedge clk) disable iff (rst || clear)
    issue_fire |-> issue_warp_id < NUM_WARPS);

  assert property (@(posedge clk) disable iff (rst || clear)
    issue_fire |-> warp_active[issue_warp_id] &&
                   !warp_done[issue_warp_id] &&
                   !warp_error[issue_warp_id]);

  assert property (@(posedge clk) disable iff (rst || clear)
    issue_fire && issue_instruction.opcode == OP_END
    |=> warp_done[$past(issue_warp_id)]);

  assert property (@(posedge clk) disable iff (rst || clear)
    issue_fire && !opcode_is_legal(issue_instruction.opcode)
    |=> warp_error[$past(issue_warp_id)]);

  assert property (@(posedge clk) disable iff (rst || clear)
    done |-> launch_mask != '0 &&
             (((warp_done | warp_error) & launch_mask) == launch_mask) &&
             !busy);

  assert property (@(posedge clk) disable iff (rst || clear)
    counters.completed_warps <= NUM_WARPS);

  assert property (@(posedge clk) disable iff (rst || clear)
    !$isunknown({
      issue_fire,
      busy,
      done,
      warp_done,
      warp_error
    }));

endmodule
