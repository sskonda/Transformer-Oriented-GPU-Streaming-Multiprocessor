module tensor_core #(
  parameter int unsigned M = warpforge_pkg::TENSOR_M,
  parameter int unsigned N = warpforge_pkg::TENSOR_N,
  parameter int unsigned K = warpforge_pkg::TENSOR_K,
  parameter int unsigned INPUT_WIDTH = warpforge_pkg::TENSOR_INPUT_WIDTH,
  parameter int unsigned ACC_WIDTH = warpforge_pkg::TENSOR_ACC_WIDTH,
  parameter int unsigned PIPELINE_LATENCY =
      warpforge_pkg::TENSOR_PIPELINE_LATENCY
) (
  input  logic clk,
  input  logic rst,
  input  logic clear,
  input  logic in_valid,
  output logic in_ready,
  input  wire logic signed [M-1:0][K-1:0][INPUT_WIDTH-1:0] matrix_a,
  input  wire logic signed [K-1:0][N-1:0][INPUT_WIDTH-1:0] matrix_b,
  output logic out_valid,
  output logic signed [M-1:0][N-1:0][ACC_WIDTH-1:0] matrix_c,
  output logic busy
);

  localparam int unsigned TREE_LEAVES =
      (K > 1) ? (1 << $clog2(K)) : 1;
  localparam int unsigned TREE_NODES = (2 * TREE_LEAVES) - 1;

  logic signed [ACC_WIDTH-1:0] reduction_tree
      [0:M-1][0:N-1][0:TREE_NODES-1];
  logic signed [M-1:0][N-1:0][ACC_WIDTH-1:0] result_comb;

  always_comb begin
    for (int unsigned row = 0; row < M; row++) begin
      for (int unsigned col = 0; col < N; col++) begin
        for (int unsigned leaf = 0; leaf < TREE_LEAVES; leaf++) begin
          if (leaf < K) begin
            reduction_tree[row][col][TREE_LEAVES-1+leaf] =
                $signed(matrix_a[row][leaf]) * $signed(matrix_b[leaf][col]);
          end else begin
            reduction_tree[row][col][TREE_LEAVES-1+leaf] = '0;
          end
        end

        for (int node = TREE_LEAVES - 2; node >= 0; node--) begin
          reduction_tree[row][col][node] =
              reduction_tree[row][col][(2*node)+1] +
              reduction_tree[row][col][(2*node)+2];
        end

        result_comb[row][col] = reduction_tree[row][col][0];
      end
    end
  end

  assign in_ready = 1'b1;

  generate
    if (PIPELINE_LATENCY == 0) begin : g_bypass
      assign out_valid = in_valid;
      assign matrix_c = result_comb;
      assign busy = in_valid;
    end else begin : g_pipeline
      logic [PIPELINE_LATENCY-1:0] valid_r;
      logic signed
          [PIPELINE_LATENCY-1:0][M-1:0][N-1:0][ACC_WIDTH-1:0] result_r;

      always_ff @(posedge clk) begin
        if (rst || clear) begin
          valid_r <= '0;
        end else begin
          valid_r[0] <= in_valid;
          if (in_valid) begin
            result_r[0] <= result_comb;
          end

          for (
            int unsigned stage = 1;
            stage < PIPELINE_LATENCY;
            stage++
          ) begin
            valid_r[stage] <= valid_r[stage-1];
            if (valid_r[stage-1]) begin
              result_r[stage] <= result_r[stage-1];
            end
          end
        end
      end

      assign out_valid = valid_r[PIPELINE_LATENCY-1];
      assign matrix_c = result_r[PIPELINE_LATENCY-1];
      assign busy = valid_r != '0;
    end
  endgenerate

  initial begin
    if (M == 0 || N == 0 || K == 0) begin
      $fatal(1, "tensor_core dimensions must be greater than zero");
    end
    if (INPUT_WIDTH == 0 || ACC_WIDTH < (2 * INPUT_WIDTH)) begin
      $fatal(1, "tensor_core arithmetic widths are invalid");
    end
  end

`ifndef SYNTHESIS
  tensor_core_sva #(
    .PIPELINE_LATENCY(PIPELINE_LATENCY)
  ) assertions (
    .clk,
    .rst,
    .clear,
    .in_valid,
    .in_ready,
    .out_valid
  );
`endif

endmodule
