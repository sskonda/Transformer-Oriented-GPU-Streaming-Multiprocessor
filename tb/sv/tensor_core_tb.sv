`timescale 1ns/1ps

module tensor_core_tb;
  import warpforge_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam int signed INPUT_MAX =
      (1 << (TENSOR_INPUT_WIDTH - 1)) - 1;

  typedef logic signed
      [TENSOR_M-1:0][TENSOR_N-1:0][TENSOR_ACC_WIDTH-1:0]
      result_matrix_t;

  logic clk = 1'b0;
  logic rst;
  logic clear;
  logic in_valid;
  logic in_ready;
  logic out_valid;
  logic out_ready;
  logic busy;
  logic tree_in_valid;
  logic tree_in_ready;
  logic tree_out_valid;
  logic tree_busy;
  logic signed
      [TENSOR_M-1:0][TENSOR_K-1:0][TENSOR_INPUT_WIDTH-1:0] matrix_a;
  logic signed
      [TENSOR_K-1:0][TENSOR_N-1:0][TENSOR_INPUT_WIDTH-1:0] matrix_b;
  result_matrix_t matrix_c;
  result_matrix_t tree_matrix_c;
  result_matrix_t expected;
  result_matrix_t held_result;

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
    .out_ready,
    .matrix_c,
    .busy
  );

  tensor_core #(
    .TENSOR_ARCH(TENSOR_ARCH_TREE)
  ) tree_dut (
    .clk,
    .rst,
    .clear,
    .in_valid(tree_in_valid),
    .in_ready(tree_in_ready),
    .matrix_a,
    .matrix_b,
    .out_valid(tree_out_valid),
    .out_ready(1'b1),
    .matrix_c(tree_matrix_c),
    .busy(tree_busy)
  );

  task automatic calculate_expected(output result_matrix_t result);
    for (int unsigned row = 0; row < TENSOR_M; row++) begin
      for (int unsigned col = 0; col < TENSOR_N; col++) begin
        int signed sum;
        sum = 0;
        for (int unsigned inner = 0; inner < TENSOR_K; inner++) begin
          sum +=
              $signed(matrix_a[row][inner]) *
              $signed(matrix_b[inner][col]);
        end
        result[row][col] = sum;
      end
    end
  endtask

  task automatic check_result(
    input string test_name,
    input result_matrix_t actual,
    input result_matrix_t reference
  );
    for (int unsigned row = 0; row < TENSOR_M; row++) begin
      for (int unsigned col = 0; col < TENSOR_N; col++) begin
        if (actual[row][col] !== reference[row][col]) begin
          $fatal(
            1,
            "%s mismatch at [%0d][%0d]: expected %0d got %0d",
            test_name,
            row,
            col,
            reference[row][col],
            actual[row][col]
          );
        end
      end
    end
  endtask

  task automatic send_and_check(input string test_name);
    calculate_expected(expected);
    @(negedge clk);
    in_valid = 1'b1;
    @(negedge clk);
    in_valid = 1'b0;
    repeat (TENSOR_PIPELINE_LATENCY - 1) @(negedge clk);

    if (!out_valid) begin
      $fatal(1, "%s did not produce output at the derived latency", test_name);
    end
    check_result(test_name, matrix_c, expected);
  endtask

  task automatic set_identity_b(input int signed diagonal);
    matrix_b = '0;
    for (int unsigned index = 0; index < TENSOR_K; index++) begin
      matrix_b[index][index] = tensor_input_t'(diagonal);
    end
  endtask

  initial begin
    rst = 1'b1;
    clear = 1'b0;
    in_valid = 1'b0;
    out_ready = 1'b1;
    tree_in_valid = 1'b0;
    matrix_a = '0;
    matrix_b = '0;

    repeat (2) @(negedge clk);
    rst = 1'b0;

    for (int unsigned row = 0; row < TENSOR_M; row++) begin
      for (int unsigned col = 0; col < TENSOR_K; col++) begin
        matrix_a[row][col] = tensor_input_t'(row + col + 1);
      end
    end
    set_identity_b(1);
    send_and_check("identity");

    for (int unsigned row = 0; row < TENSOR_M; row++) begin
      for (int unsigned col = 0; col < TENSOR_K; col++) begin
        matrix_a[row][col] = tensor_input_t'($signed(row + col) - 3);
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
        matrix_a[row][inner] = tensor_input_t'(INPUT_MAX);
      end
    end
    for (int unsigned inner = 0; inner < TENSOR_K; inner++) begin
      for (int unsigned col = 0; col < TENSOR_N; col++) begin
        matrix_b[inner][col] = tensor_input_t'(INPUT_MAX);
      end
    end
    send_and_check("extreme");

    matrix_a = '0;
    matrix_b = '1;
    @(negedge clk);
    in_valid = 1'b1;
    @(negedge clk);
    matrix_a = '1;
    @(negedge clk);
    in_valid = 1'b0;
    repeat (TENSOR_PIPELINE_LATENCY - 2) @(negedge clk);
    if (!out_valid || matrix_c[0][0] != 0) begin
      $fatal(1, "first back-to-back result was incorrect");
    end
    @(negedge clk);
    if (!out_valid || matrix_c[0][0] != TENSOR_K) begin
      $fatal(1, "second back-to-back result was incorrect");
    end

    matrix_a = '1;
    matrix_b = '1;
    calculate_expected(expected);
    @(negedge clk);
    out_ready = 1'b0;
    in_valid = 1'b1;
    @(negedge clk);
    in_valid = 1'b0;
    repeat (TENSOR_PIPELINE_LATENCY - 1) @(negedge clk);
    if (!out_valid) begin
      $fatal(1, "backpressure test did not produce output");
    end
    held_result = matrix_c;
    repeat (2) begin
      @(negedge clk);
      if (!out_valid || matrix_c !== held_result) begin
        $fatal(1, "output changed while backpressured");
      end
    end
    check_result("backpressure", matrix_c, expected);
    out_ready = 1'b1;
    @(negedge clk);

    matrix_a = '1;
    matrix_b = '1;
    tree_in_valid = 1'b1;
    @(posedge clk);
    @(negedge clk);
    tree_in_valid = 1'b0;
    if (!tree_out_valid || !tree_busy) begin
      $fatal(1, "tree mode output stage did not capture the operation");
    end
    calculate_expected(expected);
    check_result("tree", tree_matrix_c, expected);
    @(negedge clk);
    if (tree_out_valid || tree_busy) begin
      $fatal(1, "tree mode output stage did not drain");
    end

    in_valid = 1'b1;
    @(negedge clk);
    in_valid = 1'b0;
    rst = 1'b1;
    @(negedge clk);
    if (out_valid || busy) begin
      $fatal(1, "reset did not flush the tensor pipeline");
    end
    rst = 1'b0;

    $display("tensor_core_tb PASS");
    $finish;
  end

endmodule
