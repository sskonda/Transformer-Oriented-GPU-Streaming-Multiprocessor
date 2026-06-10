`timescale 1ns/1ps

module tensor_core_tb;
  import warpforge_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam int signed INPUT_MAX = (1 << (TENSOR_INPUT_WIDTH - 1)) - 1;

  logic clk = 1'b0;
  logic rst;
  logic clear;
  logic in_valid;
  logic in_ready;
  logic signed
      [TENSOR_M-1:0][TENSOR_K-1:0][TENSOR_INPUT_WIDTH-1:0] matrix_a;
  logic signed
      [TENSOR_K-1:0][TENSOR_N-1:0][TENSOR_INPUT_WIDTH-1:0] matrix_b;
  logic out_valid;
  logic signed
      [TENSOR_M-1:0][TENSOR_N-1:0][TENSOR_ACC_WIDTH-1:0] matrix_c;
  logic busy;
  logic signed
      [TENSOR_M-1:0][TENSOR_N-1:0][TENSOR_ACC_WIDTH-1:0] expected;

  always #(CLK_PERIOD / 2) clk = ~clk;

  tensor_core dut (
    .clk,
    .rst,
    .clear,
    .in_valid,
    .in_ready,
    .matrix_a,
    .matrix_b,
    .out_valid,
    .matrix_c,
    .busy
  );

  task automatic calculate_expected();
    for (int unsigned row = 0; row < TENSOR_M; row++) begin
      for (int unsigned col = 0; col < TENSOR_N; col++) begin
        int signed sum;
        sum = 0;
        for (int unsigned inner = 0; inner < TENSOR_K; inner++) begin
          sum +=
              $signed(matrix_a[row][inner]) *
              $signed(matrix_b[inner][col]);
        end
        expected[row][col] = sum;
      end
    end
  endtask

  task automatic send_and_check(input string test_name);
    calculate_expected();
    in_valid = 1'b1;
    @(negedge clk);
    in_valid = 1'b0;
    repeat (TENSOR_PIPELINE_LATENCY - 1) @(negedge clk);

    if (!out_valid) begin
      $fatal(1, "%s did not produce output at the configured latency", test_name);
    end

    for (int unsigned row = 0; row < TENSOR_M; row++) begin
      for (int unsigned col = 0; col < TENSOR_N; col++) begin
        if (matrix_c[row][col] !== expected[row][col]) begin
          $fatal(
            1,
            "%s mismatch at [%0d][%0d]: expected %0d got %0d",
            test_name,
            row,
            col,
            expected[row][col],
            matrix_c[row][col]
          );
        end
      end
    end
  endtask

  task automatic set_identity_b(input int signed diagonal);
    matrix_b = '0;
    for (int unsigned index = 0; index < TENSOR_K; index++) begin
      matrix_b[index][index] = diagonal;
    end
  endtask

  initial begin
    rst = 1'b1;
    clear = 1'b0;
    in_valid = 1'b0;
    matrix_a = '0;
    matrix_b = '0;

    repeat (2) @(negedge clk);
    rst = 1'b0;

    for (int unsigned row = 0; row < TENSOR_M; row++) begin
      for (int unsigned col = 0; col < TENSOR_K; col++) begin
        matrix_a[row][col] = row + col + 1;
      end
    end
    set_identity_b(1);
    send_and_check("identity");

    for (int unsigned row = 0; row < TENSOR_M; row++) begin
      for (int unsigned col = 0; col < TENSOR_K; col++) begin
        matrix_a[row][col] = (row + col) - 3;
      end
    end
    set_identity_b(-1);
    send_and_check("signed");

    matrix_b = '0;
    send_and_check("zero");

    matrix_a = '0;
    matrix_b = '0;
    for (int unsigned row = 0; row < TENSOR_M; row++) begin
      for (int unsigned inner = 0; inner < TENSOR_K; inner++) begin
        matrix_a[row][inner] = INPUT_MAX;
      end
    end
    for (int unsigned inner = 0; inner < TENSOR_K; inner++) begin
      for (int unsigned col = 0; col < TENSOR_N; col++) begin
        matrix_b[inner][col] = INPUT_MAX;
      end
    end
    send_and_check("extreme");

    matrix_a = '0;
    matrix_b = '1;
    in_valid = 1'b1;
    @(negedge clk);
    matrix_a = '1;
    @(negedge clk);
    in_valid = 1'b0;
    while (!out_valid) begin
      @(negedge clk);
    end
    if (!out_valid || matrix_c[0][0] != 0) begin
      $fatal(1, "first back-to-back result was incorrect");
    end
    @(negedge clk);
    if (!out_valid || matrix_c[0][0] != TENSOR_K) begin
      $fatal(1, "second back-to-back result was incorrect");
    end

    $display("tensor_core_tb PASS");
    $finish;
  end

endmodule
