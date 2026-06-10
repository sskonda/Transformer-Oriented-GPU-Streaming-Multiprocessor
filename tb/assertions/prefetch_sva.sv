module prefetch_sva #(
  parameter int unsigned NUM_WARPS = warpforge_pkg::NUM_WARPS,
  parameter int unsigned NUM_TILES = warpforge_pkg::NUM_TILES,
  parameter int unsigned QUEUE_DEPTH = warpforge_pkg::PREFETCH_QUEUE_DEPTH,
  parameter int unsigned WARP_ID_WIDTH =
      (NUM_WARPS > 1) ? $clog2(NUM_WARPS) : 1,
  parameter int unsigned TILE_ID_WIDTH =
      (NUM_TILES > 1) ? $clog2(NUM_TILES) : 1
) (
  input logic clk,
  input logic rst,
  input logic clear,
  input logic req_valid,
  input logic req_ready,
  input logic [WARP_ID_WIDTH-1:0] req_warp_id,
  input logic [TILE_ID_WIDTH-1:0] req_tile_id,
  input logic fifo_push,
  input logic fifo_pop,
  input logic fifo_out_valid,
  input logic [$clog2(QUEUE_DEPTH+1)-1:0] queue_level,
  input logic global_req_valid,
  input logic global_rsp_ready,
  input logic shared_wr_valid,
  input wire logic [NUM_WARPS-1:0][NUM_TILES-1:0] tile_valid
);

  assert property (@(posedge clk)
    rst || clear |=> tile_valid == '0);

  assert property (@(posedge clk) disable iff (rst || clear)
    req_valid && req_ready |-> req_warp_id < NUM_WARPS &&
                              req_tile_id < NUM_TILES);

  assert property (@(posedge clk) disable iff (rst || clear)
    fifo_push |-> req_valid && req_ready);

  assert property (@(posedge clk) disable iff (rst || clear)
    fifo_pop |-> fifo_out_valid);

  assert property (@(posedge clk) disable iff (rst || clear)
    queue_level == QUEUE_DEPTH && !fifo_pop |-> !fifo_push);

  assert property (@(posedge clk) disable iff (rst || clear)
    queue_level <= QUEUE_DEPTH);

  assert property (@(posedge clk) disable iff (rst || clear)
    !$isunknown({
      req_ready,
      fifo_push,
      fifo_pop,
      queue_level,
      global_req_valid,
      global_rsp_ready,
      shared_wr_valid,
      tile_valid
    }));

endmodule
