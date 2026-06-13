module warp_state_table #(
  parameter int unsigned NUM_WARPS = warpforge_pkg::NUM_WARPS,
  parameter int unsigned WARP_ID_WIDTH =
      (NUM_WARPS > 1) ? $clog2(NUM_WARPS) : 1
) (
  input  logic clk,
  input  logic rst,
  input  logic clear,
  input  logic activate_valid,
  input  logic [WARP_ID_WIDTH-1:0] activate_warp_id,
  input  logic [NUM_WARPS-1:0] scoreboard_wait,
  input  logic [NUM_WARPS-1:0] tile_wait,
  input  logic [NUM_WARPS-1:0] tensor_wait,
  input  logic [NUM_WARPS-1:0] barrier_wait,
  input  logic [NUM_WARPS-1:0] done_set,
  input  logic [NUM_WARPS-1:0] error_set,
  output logic [NUM_WARPS-1:0][2:0] state,
  output logic [NUM_WARPS-1:0] active,
  output logic [NUM_WARPS-1:0] done,
  output logic [NUM_WARPS-1:0] waiting
);
  import warpforge_pkg::*;

  warp_state_e state_r [0:NUM_WARPS-1];

  function automatic logic state_is_active(input warp_state_e warp_state);
    return warp_state == WARP_ACTIVE ||
           warp_state == WARP_WAIT_SCOREBOARD ||
           warp_state == WARP_WAIT_TILE ||
           warp_state == WARP_WAIT_TENSOR ||
           warp_state == WARP_WAIT_BARRIER;
  endfunction

  function automatic logic state_is_waiting(input warp_state_e warp_state);
    return warp_state == WARP_WAIT_SCOREBOARD ||
           warp_state == WARP_WAIT_TILE ||
           warp_state == WARP_WAIT_TENSOR ||
           warp_state == WARP_WAIT_BARRIER;
  endfunction

  always_comb begin
    for (int unsigned warp = 0; warp < NUM_WARPS; warp++) begin
      state[warp] = state_r[warp];
      active[warp] = state_is_active(state_r[warp]);
      done[warp] = state_r[warp] == WARP_DONE;
      waiting[warp] = state_is_waiting(state_r[warp]);
    end
  end

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      for (int unsigned warp = 0; warp < NUM_WARPS; warp++) begin
        state_r[warp] <= WARP_IDLE;
      end
    end else begin
      for (int unsigned warp = 0; warp < NUM_WARPS; warp++) begin
        if (error_set[warp]) begin
          state_r[warp] <= WARP_ERROR;
        end else if (done_set[warp]) begin
          state_r[warp] <= WARP_DONE;
        end else if (
          activate_valid &&
          activate_warp_id == WARP_ID_WIDTH'(warp)
        ) begin
          state_r[warp] <= WARP_ACTIVE;
        end else if (state_is_active(state_r[warp])) begin
          if (barrier_wait[warp]) begin
            state_r[warp] <= WARP_WAIT_BARRIER;
          end else if (tensor_wait[warp]) begin
            state_r[warp] <= WARP_WAIT_TENSOR;
          end else if (tile_wait[warp]) begin
            state_r[warp] <= WARP_WAIT_TILE;
          end else if (scoreboard_wait[warp]) begin
            state_r[warp] <= WARP_WAIT_SCOREBOARD;
          end else begin
            state_r[warp] <= WARP_ACTIVE;
          end
        end
      end
    end
  end

  initial begin
    if (NUM_WARPS == 0) begin
      $fatal(1, "warp_state_table NUM_WARPS must be greater than zero");
    end
  end

endmodule
