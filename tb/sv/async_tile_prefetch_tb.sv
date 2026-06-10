`timescale 1ns/1ps

module async_tile_prefetch_tb;
  import warpforge_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam int unsigned QUEUE_DEPTH = 2;
  localparam int unsigned TRANSFER_WORDS = 2;
  localparam int unsigned MAX_TRANSFER_WORDS = 4;
  localparam int unsigned LENGTH_WIDTH =
      $clog2(MAX_TRANSFER_WORDS + 1);
  localparam int unsigned GLOBAL_ADDR_WIDTH = 16;
  localparam logic [GLOBAL_ADDR_WIDTH-1:0] GLOBAL_BASE = 16'h0100;
  localparam logic [SHARED_ADDR_WIDTH-1:0] SHARED_BASE = 8'h20;
  localparam logic [SHARED_DATA_WIDTH-1:0] RESPONSE_BIAS = 32'h1000_0000;
  localparam int unsigned TIMEOUT_CYCLES = 200;

  logic clk = 1'b0;
  logic rst;
  logic clear;
  logic req_valid;
  logic req_ready;
  warp_id_t req_warp_id;
  tile_id_t req_tile_id;
  logic [GLOBAL_ADDR_WIDTH-1:0] req_global_addr;
  logic [SHARED_ADDR_WIDTH-1:0] req_shared_addr;
  logic [LENGTH_WIDTH-1:0] req_length;
  logic invalidate_valid;
  warp_id_t invalidate_warp_id;
  tile_id_t invalidate_tile_id;
  logic global_req_valid;
  logic global_req_ready;
  logic [GLOBAL_ADDR_WIDTH-1:0] global_req_addr;
  logic global_rsp_valid;
  logic global_rsp_ready;
  logic [SHARED_DATA_WIDTH-1:0] global_rsp_data;
  logic shared_wr_valid;
  logic shared_wr_ready;
  logic [SHARED_ADDR_WIDTH-1:0] shared_wr_addr;
  logic [SHARED_DATA_WIDTH-1:0] shared_wr_data;
  logic [NUM_WARPS-1:0][NUM_TILES-1:0] tile_valid;
  logic [$clog2(QUEUE_DEPTH+1)-1:0] queue_level;
  logic queue_full;
  logic active_request_valid;
  warp_id_t current_warp_id;
  tile_id_t current_tile_id;
  logic [LENGTH_WIDTH-1:0] current_word_index;
  logic prefetch_busy;
  logic prefetch_stall;
  logic request_accepted;
  logic tile_completed;
  logic [SHARED_DATA_WIDTH-1:0] shared_model
      [0:(1 << SHARED_ADDR_WIDTH)-1];

  always #(CLK_PERIOD / 2) clk = ~clk;

  async_tile_prefetch #(
    .QUEUE_DEPTH(QUEUE_DEPTH),
    .MAX_TRANSFER_WORDS(MAX_TRANSFER_WORDS),
    .GLOBAL_ADDR_WIDTH(GLOBAL_ADDR_WIDTH)
  ) dut (
    .clk,
    .rst,
    .clear,
    .req_valid,
    .req_ready,
    .req_warp_id,
    .req_tile_id,
    .req_global_addr,
    .req_shared_addr,
    .req_length,
    .invalidate_valid,
    .invalidate_warp_id,
    .invalidate_tile_id,
    .global_req_valid,
    .global_req_ready,
    .global_req_addr,
    .global_rsp_valid,
    .global_rsp_ready,
    .global_rsp_data,
    .shared_wr_valid,
    .shared_wr_ready,
    .shared_wr_addr,
    .shared_wr_data,
    .tile_valid,
    .queue_level,
    .queue_full,
    .active_request_valid,
    .current_warp_id,
    .current_tile_id,
    .current_word_index,
    .prefetch_busy,
    .prefetch_stall,
    .request_accepted,
    .tile_completed
  );

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      global_rsp_valid <= 1'b0;
    end else begin
      global_rsp_valid <= 1'b0;
      if (global_req_valid && global_req_ready) begin
        global_rsp_valid <= 1'b1;
        global_rsp_data <= RESPONSE_BIAS + global_req_addr;
      end

      if (shared_wr_valid && shared_wr_ready) begin
        shared_model[shared_wr_addr] <= shared_wr_data;
      end
    end
  end

  task automatic send_request(
    input tile_id_t tile_id,
    input logic [GLOBAL_ADDR_WIDTH-1:0] global_base,
    input logic [SHARED_ADDR_WIDTH-1:0] shared_base
  );
    @(negedge clk);
    req_valid = 1'b1;
    req_warp_id = '0;
    req_tile_id = tile_id;
    req_global_addr = global_base;
    req_shared_addr = shared_base;
    req_length = TRANSFER_WORDS;

    do begin
      @(posedge clk);
    end while (!req_ready);
    @(negedge clk);
    req_valid = 1'b0;
  endtask

  task automatic wait_for_tile(input tile_id_t tile_id);
    int unsigned cycles;
    cycles = 0;
    while (!tile_valid[0][tile_id] && cycles < TIMEOUT_CYCLES) begin
      @(negedge clk);
      cycles++;
    end
    if (!tile_valid[0][tile_id]) begin
      $fatal(1, "timed out waiting for tile %0d", tile_id);
    end
  endtask

  initial begin
    rst = 1'b1;
    clear = 1'b0;
    req_valid = 1'b0;
    req_warp_id = '0;
    req_tile_id = '0;
    req_global_addr = '0;
    req_shared_addr = '0;
    req_length = '0;
    invalidate_valid = 1'b0;
    invalidate_warp_id = '0;
    invalidate_tile_id = '0;
    global_req_ready = 1'b0;
    shared_wr_ready = 1'b1;

    repeat (2) @(negedge clk);
    rst = 1'b0;

    send_request(tile_id_t'(0), GLOBAL_BASE, SHARED_BASE);
    send_request(
      tile_id_t'(1),
      GLOBAL_BASE + TRANSFER_WORDS,
      SHARED_BASE + TRANSFER_WORDS
    );
    send_request(
      tile_id_t'(2),
      GLOBAL_BASE + (2 * TRANSFER_WORDS),
      SHARED_BASE + (2 * TRANSFER_WORDS)
    );

    @(negedge clk);
    req_valid = 1'b1;
    req_tile_id = tile_id_t'(3);
    req_global_addr = GLOBAL_BASE + (3 * TRANSFER_WORDS);
    req_shared_addr = SHARED_BASE + (3 * TRANSFER_WORDS);
    req_length = TRANSFER_WORDS;
    @(posedge clk);
    if (!queue_full || req_ready || !prefetch_stall) begin
      $fatal(1, "prefetch queue did not apply full backpressure");
    end
    @(negedge clk);
    req_valid = 1'b0;

    global_req_ready = 1'b1;
    wait_for_tile(tile_id_t'(0));
    wait_for_tile(tile_id_t'(1));
    wait_for_tile(tile_id_t'(2));

    for (int unsigned word = 0; word < TRANSFER_WORDS; word++) begin
      if (
        shared_model[SHARED_BASE + word] !==
        RESPONSE_BIAS + GLOBAL_BASE + word
      ) begin
        $fatal(1, "prefetched shared-memory data mismatch");
      end
    end

    @(negedge clk);
    req_valid = 1'b1;
    req_tile_id = tile_id_t'(0);
    req_global_addr = GLOBAL_BASE;
    req_shared_addr = SHARED_BASE;
    req_length = TRANSFER_WORDS;
    @(posedge clk);
    if (req_ready) begin
      $fatal(1, "valid tile overwrite was accepted");
    end
    @(negedge clk);
    req_valid = 1'b0;

    invalidate_valid = 1'b1;
    invalidate_warp_id = '0;
    invalidate_tile_id = '0;
    @(negedge clk);
    invalidate_valid = 1'b0;
    if (tile_valid[0][0]) begin
      $fatal(1, "tile invalidation did not clear validity");
    end

    send_request(tile_id_t'(0), GLOBAL_BASE, SHARED_BASE);
    wait_for_tile(tile_id_t'(0));

    send_request(
      tile_id_t'(3),
      GLOBAL_BASE + (3 * TRANSFER_WORDS),
      SHARED_BASE + (3 * TRANSFER_WORDS)
    );
    wait (active_request_valid);
    @(negedge clk);
    clear = 1'b1;
    @(negedge clk);
    clear = 1'b0;
    if (prefetch_busy || tile_valid != '0 || queue_level != '0) begin
      $fatal(1, "clear did not reset prefetch state");
    end

    $display("async_tile_prefetch_tb PASS");
    $finish;
  end

  initial begin
    repeat (TIMEOUT_CYCLES * 4) @(posedge clk);
    $fatal(1, "async_tile_prefetch_tb watchdog timeout");
  end

endmodule
