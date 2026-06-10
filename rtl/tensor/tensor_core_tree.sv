module tensor_core_tree #(
  parameter int unsigned M = warpforge_pkg::TENSOR_M,
  parameter int unsigned N = warpforge_pkg::TENSOR_N,
  parameter int unsigned K = warpforge_pkg::TENSOR_K,
  parameter int unsigned INPUT_WIDTH = warpforge_pkg::TENSOR_INPUT_WIDTH,
  parameter int unsigned ACC_WIDTH = warpforge_pkg::TENSOR_ACC_WIDTH
) (
  input  wire logic signed [M-1:0][K-1:0][INPUT_WIDTH-1:0] matrix_a,
  input  wire logic signed [K-1:0][N-1:0][INPUT_WIDTH-1:0] matrix_b,
  output logic signed [M-1:0][N-1:0][ACC_WIDTH-1:0] matrix_c
);

  localparam int unsigned TREE_LEAVES =
      (K > 1) ? (1 << $clog2(K)) : 1;
  localparam int unsigned TREE_NODES = (2 * TREE_LEAVES) - 1;

  logic signed [ACC_WIDTH-1:0] reduction_tree
      [0:M-1][0:N-1][0:TREE_NODES-1];

  always_comb begin
    for (int unsigned row = 0; row < M; row++) begin
      for (int unsigned col = 0; col < N; col++) begin
        for (int unsigned leaf = 0; leaf < TREE_LEAVES; leaf++) begin
          if (leaf < K) begin
            reduction_tree[row][col][TREE_LEAVES-1+leaf] =
                $signed(matrix_a[row][leaf]) *
                $signed(matrix_b[leaf][col]);
          end else begin
            reduction_tree[row][col][TREE_LEAVES-1+leaf] = '0;
          end
        end

        for (int node = TREE_LEAVES - 2; node >= 0; node--) begin
          reduction_tree[row][col][node] =
              reduction_tree[row][col][(2*node)+1] +
              reduction_tree[row][col][(2*node)+2];
        end

        matrix_c[row][col] = reduction_tree[row][col][0];
      end
    end
  end

endmodule
