module async_tile_prefetch #(
  parameter int unsigned NUM_WARPS = warpforge_pkg::NUM_WARPS,
  parameter int unsigned NUM_TILES = warpforge_pkg::NUM_TILES,
  parameter int unsigned QUEUE_DEPTH = warpforge_pkg::PREFETCH_QUEUE_DEPTH,
  parameter int unsigned MAX_TRANSFER_WORDS =
      warpforge_pkg::PREFETCH_MAX_TRANSFER_WORDS,
  parameter int unsigned GLOBAL_ADDR_WIDTH =
      warpforge_pkg::GLOBAL_ADDR_WIDTH,
  parameter int unsigned SHARED_ADDR_WIDTH =
      warpforge_pkg::SHARED_ADDR_WIDTH,
  parameter int unsigned DATA_WIDTH = warpforge_pkg::SHARED_DATA_WIDTH,
  parameter bit ALLOW_TILE_OVERWRITE = 1'b0,
  parameter int unsigned WARP_ID_WIDTH =
      (NUM_WARPS > 1) ? $clog2(NUM_WARPS) : 1,
  parameter int unsigned TILE_ID_WIDTH =
      (NUM_TILES > 1) ? $clog2(NUM_TILES) : 1,
  parameter int unsigned LENGTH_WIDTH =
      (MAX_TRANSFER_WORDS > 1) ? $clog2(MAX_TRANSFER_WORDS + 1) : 1
) (
  input  logic clk,
  input  logic rst,
  input  logic clear,

  input  logic req_valid,
  output logic req_ready,
  input  logic [WARP_ID_WIDTH-1:0] req_warp_id,
  input  logic [TILE_ID_WIDTH-1:0] req_tile_id,
  input  logic [GLOBAL_ADDR_WIDTH-1:0] req_global_addr,
  input  logic [SHARED_ADDR_WIDTH-1:0] req_shared_addr,
  input  logic [LENGTH_WIDTH-1:0] req_length,

  input  logic invalidate_valid,
  input  logic [WARP_ID_WIDTH-1:0] invalidate_warp_id,
  input  logic [TILE_ID_WIDTH-1:0] invalidate_tile_id,

  output logic global_req_valid,
  input  logic global_req_ready,
  output logic [GLOBAL_ADDR_WIDTH-1:0] global_req_addr,
  input  logic global_rsp_valid,
  output logic global_rsp_ready,
  input  logic [DATA_WIDTH-1:0] global_rsp_data,

  output logic shared_wr_valid,
  input  logic shared_wr_ready,
  output logic [SHARED_ADDR_WIDTH-1:0] shared_wr_addr,
  output logic [DATA_WIDTH-1:0] shared_wr_data,

  output logic [NUM_WARPS-1:0][NUM_TILES-1:0] tile_valid,
  output logic [$clog2(QUEUE_DEPTH+1)-1:0] queue_level,
  output logic queue_full,
  output logic active_request_valid,
  output logic [WARP_ID_WIDTH-1:0] current_warp_id,
  output logic [TILE_ID_WIDTH-1:0] current_tile_id,
  output logic [LENGTH_WIDTH-1:0] current_word_index,
  output logic prefetch_busy,
  output logic prefetch_stall,
  output logic request_accepted,
  output logic tile_completed
);

  typedef struct packed {
    logic [WARP_ID_WIDTH-1:0] warp_id;
    logic [TILE_ID_WIDTH-1:0] tile_id;
    logic [GLOBAL_ADDR_WIDTH-1:0] global_addr;
    logic [SHARED_ADDR_WIDTH-1:0] shared_addr;
    logic [LENGTH_WIDTH-1:0] length;
  } prefetch_req_t;

  typedef enum logic [1:0] {
    PREFETCH_IDLE,
    PREFETCH_SEND_READ,
    PREFETCH_WAIT_RESPONSE,
    PREFETCH_WRITE_SHARED
  } prefetch_state_e;

  prefetch_state_e state_r;
  prefetch_req_t fifo_in_data;
  prefetch_req_t fifo_out_data;
  prefetch_req_t active_req_r;
  logic fifo_in_ready;
  logic fifo_out_valid;
  logic fifo_out_ready;
  logic fifo_push;
  logic fifo_pop;
  logic [LENGTH_WIDTH-1:0] word_index_r;
  logic [DATA_WIDTH-1:0] response_data_r;
  logic [NUM_WARPS-1:0][NUM_TILES-1:0] tile_valid_r;
  logic [NUM_WARPS-1:0][NUM_TILES-1:0] tile_pending_r;
  logic tile_completed_r;
  logic request_allowed;
  logic request_indices_valid;
  logic invalidate_indices_valid;
  localparam logic [WARP_ID_WIDTH:0] NUM_WARPS_LIMIT =
      (WARP_ID_WIDTH + 1)'(NUM_WARPS);
  localparam logic [TILE_ID_WIDTH:0] NUM_TILES_LIMIT =
      (TILE_ID_WIDTH + 1)'(NUM_TILES);
  localparam logic [LENGTH_WIDTH-1:0] MAX_TRANSFER_LENGTH =
      LENGTH_WIDTH'(MAX_TRANSFER_WORDS);
  localparam logic [$clog2(QUEUE_DEPTH+1)-1:0] QUEUE_DEPTH_LEVEL =
      $clog2(QUEUE_DEPTH+1)'(QUEUE_DEPTH);

  always_comb begin
    fifo_in_data.warp_id = req_warp_id;
    fifo_in_data.tile_id = req_tile_id;
    fifo_in_data.global_addr = req_global_addr;
    fifo_in_data.shared_addr = req_shared_addr;
    fifo_in_data.length = req_length;

    request_indices_valid =
        {1'b0, req_warp_id} < NUM_WARPS_LIMIT &&
        {1'b0, req_tile_id} < NUM_TILES_LIMIT;
    invalidate_indices_valid =
        {1'b0, invalidate_warp_id} < NUM_WARPS_LIMIT &&
        {1'b0, invalidate_tile_id} < NUM_TILES_LIMIT;
    request_allowed = 1'b0;
    if (request_indices_valid) begin
      request_allowed =
          req_length != '0 &&
          req_length <= MAX_TRANSFER_LENGTH &&
          !tile_pending_r[req_warp_id][req_tile_id] &&
          (ALLOW_TILE_OVERWRITE ||
           !tile_valid_r[req_warp_id][req_tile_id]);
    end

    req_ready = !rst && !clear && fifo_in_ready && request_allowed;
    request_accepted = req_valid && req_ready;
    fifo_out_ready = state_r == PREFETCH_IDLE;
    prefetch_stall = req_valid && !req_ready;
    fifo_push = request_accepted;
    fifo_pop = fifo_out_valid && fifo_out_ready;

    global_req_valid = state_r == PREFETCH_SEND_READ;
    global_req_addr =
        active_req_r.global_addr + GLOBAL_ADDR_WIDTH'(word_index_r);
    global_rsp_ready = state_r == PREFETCH_WAIT_RESPONSE;
    shared_wr_valid = state_r == PREFETCH_WRITE_SHARED;
    shared_wr_addr =
        active_req_r.shared_addr + SHARED_ADDR_WIDTH'(word_index_r);
    shared_wr_data = response_data_r;
  end

  fifo #(
    .WIDTH($bits(prefetch_req_t)),
    .DEPTH(QUEUE_DEPTH)
  ) request_fifo (
    .clk,
    .rst,
    .clear,
    .in_valid(fifo_push),
    .in_ready(fifo_in_ready),
    .in_data(fifo_in_data),
    .out_valid(fifo_out_valid),
    .out_ready(fifo_out_ready),
    .out_data(fifo_out_data),
    .level(queue_level)
  );

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      state_r <= PREFETCH_IDLE;
      active_req_r <= '0;
      word_index_r <= '0;
      tile_valid_r <= '0;
      tile_pending_r <= '0;
      tile_completed_r <= 1'b0;
    end else begin
      tile_completed_r <= 1'b0;

      if (request_accepted) begin
        tile_pending_r[req_warp_id][req_tile_id] <= 1'b1;
        if (ALLOW_TILE_OVERWRITE) begin
          tile_valid_r[req_warp_id][req_tile_id] <= 1'b0;
        end
      end

      unique case (state_r)
        PREFETCH_IDLE: begin
          if (fifo_out_valid) begin
            active_req_r <= fifo_out_data;
            word_index_r <= '0;
            state_r <= PREFETCH_SEND_READ;
          end
        end

        PREFETCH_SEND_READ: begin
          if (global_req_ready) begin
            state_r <= PREFETCH_WAIT_RESPONSE;
          end
        end

        PREFETCH_WAIT_RESPONSE: begin
          if (global_rsp_valid) begin
            response_data_r <= global_rsp_data;
            state_r <= PREFETCH_WRITE_SHARED;
          end
        end

        PREFETCH_WRITE_SHARED: begin
          if (shared_wr_ready) begin
            if (word_index_r + 1'b1 == active_req_r.length) begin
              tile_valid_r[active_req_r.warp_id][active_req_r.tile_id]
                  <= 1'b1;
              tile_pending_r[active_req_r.warp_id][active_req_r.tile_id]
                  <= 1'b0;
              tile_completed_r <= 1'b1;
              state_r <= PREFETCH_IDLE;
            end else begin
              word_index_r <= word_index_r + 1'b1;
              state_r <= PREFETCH_SEND_READ;
            end
          end
        end

        default: begin
          state_r <= PREFETCH_IDLE;
        end
      endcase

      if (invalidate_valid && invalidate_indices_valid) begin
        tile_valid_r[invalidate_warp_id][invalidate_tile_id] <= 1'b0;
      end
    end
  end

  assign tile_valid = tile_valid_r;
  assign queue_full = queue_level == QUEUE_DEPTH_LEVEL;
  assign active_request_valid = state_r != PREFETCH_IDLE;
  assign current_warp_id = active_req_r.warp_id;
  assign current_tile_id = active_req_r.tile_id;
  assign current_word_index = word_index_r;
  assign prefetch_busy = active_request_valid || fifo_out_valid;
  assign tile_completed = tile_completed_r;

  initial begin
    if (NUM_WARPS == 0 || NUM_TILES == 0 || QUEUE_DEPTH == 0) begin
      $fatal(1, "async_tile_prefetch dimensions must be greater than zero");
    end
    if (MAX_TRANSFER_WORDS == 0 || DATA_WIDTH == 0) begin
      $fatal(1, "async_tile_prefetch transfer configuration is invalid");
    end
  end

`ifndef SYNTHESIS
  prefetch_sva #(
    .NUM_WARPS(NUM_WARPS),
    .NUM_TILES(NUM_TILES),
    .QUEUE_DEPTH(QUEUE_DEPTH),
    .WARP_ID_WIDTH(WARP_ID_WIDTH),
    .TILE_ID_WIDTH(TILE_ID_WIDTH)
  ) assertions (
    .clk,
    .rst,
    .clear,
    .req_valid,
    .req_ready,
    .req_warp_id,
    .req_tile_id,
    .fifo_push,
    .fifo_pop,
    .fifo_out_valid,
    .queue_level,
    .global_req_valid,
    .global_rsp_ready,
    .shared_wr_valid,
    .tile_valid
  );
`endif

endmodule
