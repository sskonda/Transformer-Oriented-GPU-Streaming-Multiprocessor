`timescale 1ns/1ps

module tensor_core_parameter_case #(
  parameter int unsigned K = 1,
  parameter warpforge_pkg::tensor_arch_e TENSOR_ARCH =
      warpforge_pkg::TENSOR_ARCH_PIPELINED_TREE
) (
  input  logic clk,
  input  logic rst,
  output logic done
);
  localparam int unsigned INPUT_WIDTH = 8;
  localparam int unsigned ACC_WIDTH = 32;

  logic clear;
  logic in_valid;
  logic in_ready;
  logic out_valid;
  logic out_ready;
  logic signed [0:0][K-1:0][INPUT_WIDTH-1:0] matrix_a;
  logic signed [K-1:0][0:0][INPUT_WIDTH-1:0] matrix_b;
  logic signed [0:0][0:0][ACC_WIDTH-1:0] matrix_c;
  int signed expected;

  tensor_core #(
    .M(1),
    .N(1),
    .K(K),
    .INPUT_WIDTH(INPUT_WIDTH),
    .ACC_WIDTH(ACC_WIDTH),
    .TENSOR_ARCH(TENSOR_ARCH)
  ) dut (
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
    .busy()
  );

  initial begin
    clear = 1'b0;
    in_valid = 1'b0;
    out_ready = 1'b1;
    matrix_a = '0;
    matrix_b = '0;
    expected = 0;
    done = 1'b0;

    wait (!rst);
    for (int unsigned inner = 0; inner < K; inner++) begin
      int signed a_value;
      int signed b_value;
      a_value = $signed(inner) - 2;
      b_value = (inner[0]) ? -2 : 3;
      matrix_a[0][inner] = INPUT_WIDTH'(a_value);
      matrix_b[inner][0] = INPUT_WIDTH'(b_value);
      expected += a_value * b_value;
    end

    @(negedge clk);
    in_valid = 1'b1;
    while (!in_ready) begin
      @(negedge clk);
    end
    @(negedge clk);
    in_valid = 1'b0;

    for (int unsigned cycles = 0; cycles < 20 && !out_valid; cycles++) begin
      @(negedge clk);
    end
    if (!out_valid) begin
      $fatal(1, "K=%0d arch=%0d timed out", K, TENSOR_ARCH);
    end
    if ($signed(matrix_c[0][0]) !== expected) begin
      $fatal(
        1,
        "K=%0d arch=%0d expected %0d got %0d",
        K,
        TENSOR_ARCH,
        expected,
        $signed(matrix_c[0][0])
      );
    end
    done = 1'b1;
  end
endmodule

module tensor_core_parameter_tb;
  import warpforge_pkg::*;

  localparam time CLK_PERIOD = 10ns;

  logic clk = 1'b0;
  logic rst;
  logic [5:0] done;

  always #(CLK_PERIOD / 2) clk = ~clk;

  tensor_core_parameter_case #(
    .K(1),
    .TENSOR_ARCH(TENSOR_ARCH_PIPELINED_TREE)
  ) pipeline_k1 (.clk, .rst, .done(done[0]));

  tensor_core_parameter_case #(
    .K(3),
    .TENSOR_ARCH(TENSOR_ARCH_PIPELINED_TREE)
  ) pipeline_k3 (.clk, .rst, .done(done[1]));

  tensor_core_parameter_case #(
    .K(5),
    .TENSOR_ARCH(TENSOR_ARCH_PIPELINED_TREE)
  ) pipeline_k5 (.clk, .rst, .done(done[2]));

  tensor_core_parameter_case #(
    .K(1),
    .TENSOR_ARCH(TENSOR_ARCH_TREE)
  ) tree_k1 (.clk, .rst, .done(done[3]));

  tensor_core_parameter_case #(
    .K(3),
    .TENSOR_ARCH(TENSOR_ARCH_TREE)
  ) tree_k3 (.clk, .rst, .done(done[4]));

  tensor_core_parameter_case #(
    .K(5),
    .TENSOR_ARCH(TENSOR_ARCH_TREE)
  ) tree_k5 (.clk, .rst, .done(done[5]));

  initial begin
    rst = 1'b1;
    repeat (2) @(negedge clk);
    rst = 1'b0;
    wait (&done);
    $display("tensor_core_parameter_tb PASS");
    $finish;
  end
endmodule
