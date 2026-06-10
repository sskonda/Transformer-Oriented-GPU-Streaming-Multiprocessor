module tensor_core_pipelined_tree #(
  parameter int unsigned M = warpforge_pkg::TENSOR_M,
  parameter int unsigned N = warpforge_pkg::TENSOR_N,
  parameter int unsigned K = warpforge_pkg::TENSOR_K,
  parameter int unsigned INPUT_WIDTH = warpforge_pkg::TENSOR_INPUT_WIDTH,
  parameter int unsigned ACC_WIDTH = warpforge_pkg::TENSOR_ACC_WIDTH
) (
  input  logic clk,
  input  logic rst,
  input  logic clear,
  input  logic in_valid,
  output logic in_ready,
  input  wire logic signed [M-1:0][K-1:0][INPUT_WIDTH-1:0] matrix_a,
  input  wire logic signed [K-1:0][N-1:0][INPUT_WIDTH-1:0] matrix_b,
  output logic out_valid,
  input  logic out_ready,
  output logic signed [M-1:0][N-1:0][ACC_WIDTH-1:0] matrix_c,
  output logic busy
);

  localparam int unsigned TREE_LEAVES =
      (K > 1) ? (1 << $clog2(K)) : 1;
  localparam int unsigned REDUCTION_LEVELS = $clog2(TREE_LEAVES);
  localparam int unsigned PIPELINE_STAGES = REDUCTION_LEVELS + 1;

  logic [PIPELINE_STAGES-1:0] valid_r;
  logic [PIPELINE_STAGES-1:0] stage_ready;
  logic signed [ACC_WIDTH-1:0] data_r
      [0:PIPELINE_STAGES-1][0:M-1][0:N-1][0:TREE_LEAVES-1];

  always_comb begin
    stage_ready = '0;
    stage_ready[PIPELINE_STAGES-1] =
        out_ready || !valid_r[PIPELINE_STAGES-1];
    for (int stage = PIPELINE_STAGES - 2; stage >= 0; stage--) begin
      stage_ready[stage] = !valid_r[stage] || stage_ready[stage+1];
    end
  end

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      valid_r <= '0;
    end else begin
      if (stage_ready[0]) begin
        valid_r[0] <= in_valid;
        if (in_valid) begin
          for (int unsigned row = 0; row < M; row++) begin
            for (int unsigned col = 0; col < N; col++) begin
              for (
                int unsigned leaf = 0;
                leaf < TREE_LEAVES;
                leaf++
              ) begin
                if (leaf < K) begin
                  data_r[0][row][col][leaf] <=
                      $signed(matrix_a[row][leaf]) *
                      $signed(matrix_b[leaf][col]);
                end else begin
                  data_r[0][row][col][leaf] <= '0;
                end
              end
            end
          end
        end
      end

      for (
        int unsigned stage = 1;
        stage < PIPELINE_STAGES;
        stage++
      ) begin
        if (stage_ready[stage]) begin
          valid_r[stage] <= valid_r[stage-1];
          if (valid_r[stage-1]) begin
            for (int unsigned row = 0; row < M; row++) begin
              for (int unsigned col = 0; col < N; col++) begin
                for (
                  int unsigned node = 0;
                  node < TREE_LEAVES;
                  node++
                ) begin
                  if (node < (TREE_LEAVES >> stage)) begin
                    data_r[stage][row][col][node] <=
                        data_r[stage-1][row][col][2*node] +
                        data_r[stage-1][row][col][(2*node)+1];
                  end else begin
                    data_r[stage][row][col][node] <= '0;
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  always_comb begin
    for (int unsigned row = 0; row < M; row++) begin
      for (int unsigned col = 0; col < N; col++) begin
        matrix_c[row][col] =
            data_r[PIPELINE_STAGES-1][row][col][0];
      end
    end
  end

  assign in_ready = stage_ready[0] && !rst && !clear;
  assign out_valid = valid_r[PIPELINE_STAGES-1] && !rst && !clear;
  assign busy = valid_r != '0;

endmodule
