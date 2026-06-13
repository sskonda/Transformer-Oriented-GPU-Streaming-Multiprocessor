module tensor_tile_buffer #(
  parameter int unsigned NUM_WARPS = warpforge_pkg::NUM_WARPS,
  parameter int unsigned NUM_TILES = warpforge_pkg::NUM_TILES,
  parameter int unsigned M = warpforge_pkg::TENSOR_M,
  parameter int unsigned N = warpforge_pkg::TENSOR_N,
  parameter int unsigned K = warpforge_pkg::TENSOR_K,
  parameter int unsigned INPUT_WIDTH = warpforge_pkg::TENSOR_INPUT_WIDTH,
  parameter int unsigned DATA_WIDTH = warpforge_pkg::SHARED_DATA_WIDTH,
  parameter int unsigned TILE_WORDS = warpforge_pkg::TENSOR_TILE_WORDS,
  parameter int unsigned WARP_ID_WIDTH =
      (NUM_WARPS > 1) ? $clog2(NUM_WARPS) : 1,
  parameter int unsigned TILE_ID_WIDTH =
      (NUM_TILES > 1) ? $clog2(NUM_TILES) : 1,
  parameter int unsigned WORD_INDEX_WIDTH =
      $clog2(warpforge_pkg::PREFETCH_MAX_TRANSFER_WORDS + 1)
) (
  input  logic clk,
  input  logic write_valid,
  input  logic [WARP_ID_WIDTH-1:0] write_warp_id,
  input  logic [TILE_ID_WIDTH-1:0] write_tile_id,
  input  logic [WORD_INDEX_WIDTH-1:0] write_word_index,
  input  logic [DATA_WIDTH-1:0] write_data,
  input  logic [WARP_ID_WIDTH-1:0] read_warp_id,
  input  logic [TILE_ID_WIDTH-1:0] read_tile_id,
  output logic signed [M-1:0][K-1:0][INPUT_WIDTH-1:0] matrix_a,
  output logic signed [K-1:0][N-1:0][INPUT_WIDTH-1:0] matrix_b
);

  localparam int unsigned ELEMENTS_PER_WORD = DATA_WIDTH / INPUT_WIDTH;
  localparam int unsigned A_ELEMENTS = M * K;
  localparam int unsigned TILE_WORD_INDEX_WIDTH =
      (TILE_WORDS > 1) ? $clog2(TILE_WORDS) : 1;
  localparam logic [WORD_INDEX_WIDTH-1:0] TILE_WORDS_LIMIT =
      WORD_INDEX_WIDTH'(TILE_WORDS);

  logic [DATA_WIDTH-1:0] storage
      [0:NUM_WARPS-1][0:NUM_TILES-1][0:TILE_WORDS-1];

  always_ff @(posedge clk) begin
    if (write_valid && write_word_index < TILE_WORDS_LIMIT) begin
      storage[write_warp_id][write_tile_id]
          [TILE_WORD_INDEX_WIDTH'(write_word_index)]
          <= write_data;
    end
  end

  always_comb begin
    matrix_a = '0;
    matrix_b = '0;

    for (int unsigned row = 0; row < M; row++) begin
      for (int unsigned inner = 0; inner < K; inner++) begin
        int unsigned element;
        int unsigned word_index;
        int unsigned lane;
        element = (row * K) + inner;
        word_index = element / ELEMENTS_PER_WORD;
        lane = element % ELEMENTS_PER_WORD;
        matrix_a[row][inner] = $signed(
          storage[read_warp_id][read_tile_id]
              [word_index][(lane*INPUT_WIDTH) +: INPUT_WIDTH]
        );
      end
    end

    for (int unsigned inner = 0; inner < K; inner++) begin
      for (int unsigned col = 0; col < N; col++) begin
        int unsigned element;
        int unsigned word_index;
        int unsigned lane;
        element = A_ELEMENTS + (inner * N) + col;
        word_index = element / ELEMENTS_PER_WORD;
        lane = element % ELEMENTS_PER_WORD;
        matrix_b[inner][col] = $signed(
          storage[read_warp_id][read_tile_id]
              [word_index][(lane*INPUT_WIDTH) +: INPUT_WIDTH]
        );
      end
    end
  end

  initial begin
    if (
      NUM_WARPS == 0 ||
      NUM_TILES == 0 ||
      TILE_WORDS == 0 ||
      DATA_WIDTH % INPUT_WIDTH != 0
    ) begin
      $fatal(1, "tensor_tile_buffer parameters are invalid");
    end
  end

endmodule
