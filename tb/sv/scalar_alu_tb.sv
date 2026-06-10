`timescale 1ns/1ps

module scalar_alu_tb;
  import warpforge_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam int unsigned DATA_WIDTH = 32;

  logic clk = 1'b0;
  logic rst;
  logic clear;
  logic in_valid;
  logic in_ready;
  opcode_e in_opcode;
  logic signed [DATA_WIDTH-1:0] in_src0;
  logic signed [DATA_WIDTH-1:0] in_src1;
  logic signed [DATA_WIDTH-1:0] in_src2;
  warp_id_t in_warp_id;
  reg_idx_t in_dst;
  logic out_valid;
  logic out_ready;
  logic signed [DATA_WIDTH-1:0] out_data;
  warp_id_t out_warp_id;
  reg_idx_t out_dst;

  always #(CLK_PERIOD / 2) clk = ~clk;

  scalar_alu #(
    .DATA_WIDTH(DATA_WIDTH),
    .LATENCY(2)
  ) dut (
    .clk,
    .rst,
    .clear,
    .in_valid,
    .in_ready,
    .in_opcode,
    .in_src0,
    .in_src1,
    .in_src2,
    .in_warp_id,
    .in_dst,
    .out_valid,
    .out_ready,
    .out_data,
    .out_warp_id,
    .out_dst
  );

  task automatic send_operation(
    input opcode_e opcode,
    input int signed src0,
    input int signed src1,
    input int signed src2,
    input warp_id_t warp_id,
    input reg_idx_t dst
  );
    @(negedge clk);
    in_valid = 1'b1;
    in_opcode = opcode;
    in_src0 = src0;
    in_src1 = src1;
    in_src2 = src2;
    in_warp_id = warp_id;
    in_dst = dst;
    do begin
      @(posedge clk);
    end while (!in_ready);
    @(negedge clk);
    in_valid = 1'b0;
  endtask

  task automatic check_output(
    input int signed expected_data,
    input warp_id_t expected_warp,
    input reg_idx_t expected_dst
  );
    while (!out_valid) begin
      @(negedge clk);
    end
    if (
      $signed(out_data) != expected_data ||
      out_warp_id != expected_warp ||
      out_dst != expected_dst
    ) begin
      $fatal(
        1,
        "scalar output mismatch: data=%0d warp=%0d dst=%0d",
        $signed(out_data),
        out_warp_id,
        out_dst
      );
    end
    @(negedge clk);
  endtask

  initial begin
    rst = 1'b1;
    clear = 1'b0;
    in_valid = 1'b0;
    in_opcode = OP_NOP;
    in_src0 = '0;
    in_src1 = '0;
    in_src2 = '0;
    in_warp_id = '0;
    in_dst = '0;
    out_ready = 1'b1;

    repeat (2) @(negedge clk);
    rst = 1'b0;

    send_operation(
      OP_ALU_ADD,
      -5,
      3,
      0,
      warp_id_t'(1),
      reg_idx_t'(4)
    );
    check_output(-2, warp_id_t'(1), reg_idx_t'(4));

    send_operation(
      OP_ALU_MUL,
      -4,
      7,
      0,
      warp_id_t'(2),
      reg_idx_t'(5)
    );
    check_output(-28, warp_id_t'(2), reg_idx_t'(5));

    send_operation(
      OP_ALU_MAD,
      -3,
      5,
      2,
      warp_id_t'(3),
      reg_idx_t'(6)
    );
    check_output(-13, warp_id_t'(3), reg_idx_t'(6));

    @(negedge clk);
    in_valid = 1'b1;
    in_opcode = OP_ALU_ADD;
    in_src0 = 10;
    in_src1 = 20;
    in_src2 = 0;
    in_warp_id = '0;
    in_dst = reg_idx_t'(7);
    @(posedge clk);
    @(negedge clk);
    in_opcode = OP_ALU_MUL;
    in_src0 = 6;
    in_src1 = 7;
    in_dst = reg_idx_t'(8);
    @(posedge clk);
    @(negedge clk);
    in_valid = 1'b0;

    check_output(30, '0, reg_idx_t'(7));
    check_output(42, '0, reg_idx_t'(8));

    out_ready = 1'b0;
    send_operation(
      OP_ALU_ADD,
      100,
      23,
      0,
      warp_id_t'(1),
      reg_idx_t'(9)
    );
    while (!out_valid) begin
      @(negedge clk);
    end
    repeat (3) begin
      logic signed [DATA_WIDTH-1:0] held_data;
      held_data = out_data;
      @(negedge clk);
      if (!out_valid || out_data != held_data) begin
        $fatal(1, "scalar output changed under backpressure");
      end
    end
    out_ready = 1'b1;
    @(negedge clk);

    in_valid = 1'b1;
    in_opcode = OP_TENSOR_MMA;
    @(negedge clk);
    if (in_ready) begin
      $fatal(1, "scalar ALU accepted a non-scalar opcode");
    end
    in_valid = 1'b0;

    $display("scalar_alu_tb PASS");
    $finish;
  end

  initial begin
    repeat (200) @(posedge clk);
    $fatal(1, "scalar_alu_tb watchdog timeout");
  end

endmodule
