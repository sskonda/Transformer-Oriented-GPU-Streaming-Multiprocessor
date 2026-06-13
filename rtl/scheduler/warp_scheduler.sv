module warp_scheduler #(
  parameter int unsigned NUM_WARPS = warpforge_pkg::NUM_WARPS,
  parameter int unsigned WARP_ID_WIDTH =
      (NUM_WARPS > 1) ? $clog2(NUM_WARPS) : 1
) (
  input  logic clk,
  input  logic rst,
  input  logic clear,
  input  warpforge_pkg::scheduler_policy_e policy,
  input  logic [NUM_WARPS-1:0] active,
  input  logic [NUM_WARPS-1:0] done,
  input  logic [NUM_WARPS-1:0] instruction_valid,
  input  logic [NUM_WARPS-1:0] scoreboard_stall,
  input  logic [NUM_WARPS-1:0] tile_wait,
  input  logic [NUM_WARPS-1:0] tensor_wait,
  input  logic [NUM_WARPS-1:0] prefetch_wait,
  input  logic [NUM_WARPS-1:0] barrier_wait,
  input  logic [NUM_WARPS-1:0] tile_preferred,
  input  logic issue_accept,
  output logic issue_valid,
  output logic [WARP_ID_WIDTH-1:0] selected_warp_id,
  output logic [NUM_WARPS-1:0] ready,
  output logic [WARP_ID_WIDTH-1:0] round_robin_pointer
);
  import warpforge_pkg::*;

  logic [WARP_ID_WIDTH-1:0] rr_pointer_r;
  logic [NUM_WARPS-1:0] preferred_ready;
  logic [NUM_WARPS-1:0] search_vector;

  always_comb begin
    ready =
        active &
        ~done &
        instruction_valid &
        ~scoreboard_stall &
        ~tile_wait &
        ~tensor_wait &
        ~prefetch_wait &
        ~barrier_wait;
    preferred_ready = ready & tile_preferred;
    search_vector = ready;
    issue_valid = 1'b0;
    selected_warp_id = '0;

    if (policy == SCHED_MEMORY_AWARE && preferred_ready != '0) begin
      search_vector = preferred_ready;
    end

    if (!rst && !clear) begin
      unique case (policy)
        SCHED_ROUND_ROBIN: begin
          for (int unsigned offset = 0; offset < NUM_WARPS; offset++) begin
            int unsigned candidate;
            candidate = int'(rr_pointer_r) + offset;
            if (candidate >= NUM_WARPS) begin
              candidate = candidate - NUM_WARPS;
            end
            if (!issue_valid && search_vector[candidate]) begin
              issue_valid = 1'b1;
              selected_warp_id = WARP_ID_WIDTH'(candidate);
            end
          end
        end

        SCHED_GREEDY, SCHED_MEMORY_AWARE: begin
          for (int unsigned warp = 0; warp < NUM_WARPS; warp++) begin
            if (!issue_valid && search_vector[warp]) begin
              issue_valid = 1'b1;
              selected_warp_id = WARP_ID_WIDTH'(warp);
            end
          end
        end

        default: begin
          issue_valid = 1'b0;
          selected_warp_id = '0;
        end
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      rr_pointer_r <= '0;
    end else if (
      policy == SCHED_ROUND_ROBIN &&
      issue_valid &&
      issue_accept
    ) begin
      if (selected_warp_id == WARP_ID_WIDTH'(NUM_WARPS - 1)) begin
        rr_pointer_r <= '0;
      end else begin
        rr_pointer_r <= selected_warp_id + 1'b1;
      end
    end
  end

  assign round_robin_pointer = rr_pointer_r;

  initial begin
    if (NUM_WARPS == 0) begin
      $fatal(1, "warp_scheduler NUM_WARPS must be greater than zero");
    end
  end

`ifndef SYNTHESIS
  scheduler_sva #(
    .NUM_WARPS(NUM_WARPS),
    .WARP_ID_WIDTH(WARP_ID_WIDTH)
  ) assertions (
    .clk,
    .rst,
    .clear,
    .policy,
    .active,
    .done,
    .scoreboard_stall,
    .tile_wait,
    .tensor_wait,
    .prefetch_wait,
    .barrier_wait,
    .issue_valid,
    .selected_warp_id,
    .ready,
    .round_robin_pointer
  );
`endif

endmodule
