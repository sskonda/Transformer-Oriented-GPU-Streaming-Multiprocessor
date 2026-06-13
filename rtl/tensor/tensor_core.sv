module tensor_core #(
  parameter int unsigned M = warpforge_pkg::TENSOR_M,
  parameter int unsigned N = warpforge_pkg::TENSOR_N,
  parameter int unsigned K = warpforge_pkg::TENSOR_K,
  parameter int unsigned INPUT_WIDTH = warpforge_pkg::TENSOR_INPUT_WIDTH,
  parameter int unsigned ACC_WIDTH = warpforge_pkg::TENSOR_ACC_WIDTH,
  parameter warpforge_pkg::tensor_arch_e TENSOR_ARCH =
      warpforge_pkg::TENSOR_ARCH_PIPELINED_TREE
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
  import warpforge_pkg::*;

  localparam int unsigned PIPELINE_STAGES = 1 + $clog2(K);
  localparam int unsigned MIN_ACC_WIDTH =
      (2 * INPUT_WIDTH) + ((K > 1) ? $clog2(K) : 0);

  generate
    if (TENSOR_ARCH == TENSOR_ARCH_TREE) begin : g_tree
      logic signed [M-1:0][N-1:0][ACC_WIDTH-1:0] result;
      logic signed [M-1:0][N-1:0][ACC_WIDTH-1:0] result_r;
      logic valid_r;

      tensor_core_tree #(
        .M(M),
        .N(N),
        .K(K),
        .INPUT_WIDTH(INPUT_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
      ) datapath (
        .matrix_a,
        .matrix_b,
        .matrix_c(result)
      );

      assign in_ready = (!valid_r || out_ready) && !rst && !clear;
      assign out_valid = valid_r && !rst && !clear;
      assign matrix_c = result_r;
      assign busy = valid_r;

      always_ff @(posedge clk) begin
        if (rst || clear) begin
          valid_r <= 1'b0;
        end else if (in_ready) begin
          valid_r <= in_valid;
          if (in_valid) begin
            result_r <= result;
          end
        end
      end
    end else if (TENSOR_ARCH == TENSOR_ARCH_PIPELINED_TREE) begin : g_pipeline
      tensor_core_pipelined_tree #(
        .M(M),
        .N(N),
        .K(K),
        .INPUT_WIDTH(INPUT_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
      ) datapath (
        .clk,
        .rst,
        .clear,
        .in_valid,
        .in_ready,
        .matrix_a,
        .matrix_b,
        .out_valid,
        .out_ready,
        .matrix_c,
        .busy
      );
    end else begin : g_unsupported
      assign in_ready = 1'b0;
      assign out_valid = 1'b0;
      assign matrix_c = '0;
      assign busy = 1'b0;
    end
  endgenerate

  initial begin
    if (M == 0 || N == 0 || K == 0) begin
      $fatal(1, "tensor_core dimensions must be greater than zero");
    end
    if (INPUT_WIDTH == 0 || ACC_WIDTH < MIN_ACC_WIDTH) begin
      $fatal(1, "tensor_core arithmetic widths are invalid");
    end
    if (TENSOR_ARCH == TENSOR_ARCH_SYSTOLIC) begin
      $fatal(1, "tensor_core systolic architecture is not implemented");
    end
  end

`ifndef SYNTHESIS
  tensor_core_sva #(
    .M(M),
    .N(N),
    .ACC_WIDTH(ACC_WIDTH),
    .PIPELINE_STAGES(PIPELINE_STAGES),
    .TENSOR_ARCH(TENSOR_ARCH)
  ) assertions (
    .clk,
    .rst,
    .clear,
    .in_valid,
    .in_ready,
    .out_valid,
    .out_ready,
    .matrix_c
  );
`endif

endmodule
