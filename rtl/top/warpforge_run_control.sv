module warpforge_run_control (
  input  logic clk,
  input  logic rst,
  input  logic clear,
  input  logic start,
  input  logic busy,
  input  logic [warpforge_pkg::NUM_WARPS-1:0] instruction_valid,
  input  logic issue_fire,
  input  warpforge_pkg::warp_id_t issue_warp_id,
  input  warpforge_pkg::opcode_e issue_opcode,
  input  logic [warpforge_pkg::NUM_WARPS-1:0] warp_done,
  input  logic [warpforge_pkg::NUM_WARPS-1:0] warp_error,
  output logic [warpforge_pkg::NUM_WARPS-1:0] launch_mask,
  output logic launch_pending,
  output warpforge_pkg::warp_id_t launch_index,
  output logic start_seen,
  output logic activate_valid,
  output logic [warpforge_pkg::NUM_WARPS-1:0] barrier_wait
);
  import warpforge_pkg::*;

  logic [NUM_WARPS-1:0] barrier_arrived_r;
  logic barrier_release;
  logic barrier_issue;

  always_comb begin
    barrier_release =
        barrier_arrived_r != '0 &&
        (((barrier_arrived_r | warp_done | warp_error) & launch_mask)
          == launch_mask);
    barrier_issue = issue_fire && issue_opcode == OP_BARRIER;
    activate_valid = launch_pending && launch_mask[launch_index];
    barrier_wait = barrier_arrived_r &
        {NUM_WARPS{!barrier_release}};
  end

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      launch_mask <= '0;
      launch_pending <= 1'b0;
      launch_index <= '0;
      start_seen <= 1'b0;
      barrier_arrived_r <= '0;
    end else begin
      if (start && !busy) begin
        launch_mask <= instruction_valid;
        launch_pending <= 1'b1;
        launch_index <= '0;
        start_seen <= 1'b1;
      end else if (launch_pending) begin
        if (launch_index == NUM_WARPS - 1) begin
          launch_pending <= 1'b0;
        end else begin
          launch_index <= launch_index + 1'b1;
        end
      end

      if (barrier_release) begin
        barrier_arrived_r <= '0;
      end
      if (barrier_issue) begin
        barrier_arrived_r[issue_warp_id] <= 1'b1;
      end
    end
  end

endmodule
