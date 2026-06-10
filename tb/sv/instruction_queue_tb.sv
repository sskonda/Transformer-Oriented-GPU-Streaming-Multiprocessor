`timescale 1ns/1ps

module instruction_queue_tb;
  import warpforge_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam int unsigned DEPTH = 4;
  localparam int unsigned ADDR_WIDTH = $clog2(DEPTH);

  logic clk = 1'b0;
  logic rst;
  logic clear;
  logic load_valid;
  logic load_ready;
  warp_id_t load_warp_id;
  logic [ADDR_WIDTH-1:0] load_addr;
  instruction_t load_instruction;
  logic issue_valid;
  logic issue_accept;
  warp_id_t issue_warp_id;
  instruction_t current_instruction [0:NUM_WARPS-1];
  logic [NUM_WARPS-1:0] instruction_valid;
  logic [NUM_WARPS-1:0] current_end;
  logic [NUM_WARPS-1:0] current_illegal;
  logic [NUM_WARPS-1:0][ADDR_WIDTH-1:0] pc;
  logic [NUM_WARPS-1:0] halted;
  logic [NUM_WARPS-1:0] end_issued;
  logic [NUM_WARPS-1:0] illegal_issued;
  logic [NUM_WARPS-1:0] pc_error;

  always #(CLK_PERIOD / 2) clk = ~clk;

  instruction_queue #(
    .DEPTH(DEPTH)
  ) dut (
    .clk,
    .rst,
    .clear,
    .load_valid,
    .load_ready,
    .load_warp_id,
    .load_addr,
    .load_instruction,
    .issue_valid,
    .issue_accept,
    .issue_warp_id,
    .current_instruction,
    .instruction_valid,
    .current_end,
    .current_illegal,
    .pc,
    .halted,
    .end_issued,
    .illegal_issued,
    .pc_error
  );

  function automatic instruction_t make_instruction(input opcode_e opcode);
    instruction_t instruction;
    instruction = '0;
    instruction.opcode = opcode;
    return instruction;
  endfunction

  task automatic load_program_word(
    input warp_id_t warp_id,
    input logic [ADDR_WIDTH-1:0] address,
    input instruction_t instruction
  );
    @(negedge clk);
    load_valid = 1'b1;
    load_warp_id = warp_id;
    load_addr = address;
    load_instruction = instruction;
    @(posedge clk);
    if (!load_ready) begin
      $fatal(1, "instruction load was not accepted");
    end
    @(negedge clk);
    load_valid = 1'b0;
  endtask

  task automatic issue_warp(input warp_id_t warp_id);
    @(negedge clk);
    issue_valid = 1'b1;
    issue_accept = 1'b1;
    issue_warp_id = warp_id;
    @(posedge clk);
    @(negedge clk);
    issue_valid = 1'b0;
    issue_accept = 1'b0;
  endtask

  initial begin
    rst = 1'b1;
    clear = 1'b0;
    load_valid = 1'b0;
    load_warp_id = '0;
    load_addr = '0;
    load_instruction = '0;
    issue_valid = 1'b0;
    issue_accept = 1'b0;
    issue_warp_id = '0;

    repeat (2) @(negedge clk);
    rst = 1'b0;

    load_program_word(warp_id_t'(0), 0, make_instruction(OP_NOP));
    load_program_word(warp_id_t'(0), 1, make_instruction(OP_ALU_ADD));
    load_program_word(warp_id_t'(0), 2, make_instruction(OP_END));

    for (int unsigned address = 0; address < DEPTH; address++) begin
      load_program_word(
        warp_id_t'(1),
        ADDR_WIDTH'(address),
        make_instruction(OP_NOP)
      );
    end

    load_program_word(
      warp_id_t'(2),
      0,
      make_instruction(opcode_e'(4'he))
    );

    if (!instruction_valid[0] || current_instruction[0].opcode != OP_NOP) begin
      $fatal(1, "warp 0 did not present its first instruction");
    end

    issue_warp(warp_id_t'(0));
    if (pc[0] != 1 || current_instruction[0].opcode != OP_ALU_ADD) begin
      $fatal(1, "warp 0 PC did not advance to ALU_ADD");
    end

    issue_warp(warp_id_t'(0));
    if (pc[0] != 2 || !current_end[0]) begin
      $fatal(1, "warp 0 PC did not advance to END");
    end

    issue_warp(warp_id_t'(0));
    if (!end_issued[0] || instruction_valid[0] || !halted[0]) begin
      $fatal(1, "END did not halt warp 0");
    end

    issue_warp(warp_id_t'(2));
    if (!illegal_issued[2] || instruction_valid[2] || !halted[2]) begin
      $fatal(1, "illegal instruction did not halt warp 2");
    end

    for (int unsigned count = 0; count < DEPTH; count++) begin
      issue_warp(warp_id_t'(1));
    end
    if (!pc_error[1] || instruction_valid[1] || !halted[1]) begin
      $fatal(1, "PC boundary violation was not contained");
    end

    clear = 1'b1;
    @(negedge clk);
    clear = 1'b0;
    if (pc != '0 || halted != '0 || !instruction_valid[0]) begin
      $fatal(1, "clear did not restart loaded programs");
    end

    rst = 1'b1;
    @(negedge clk);
    rst = 1'b0;
    if (instruction_valid != '0) begin
      $fatal(1, "reset did not clear loaded instruction validity");
    end

    $display("instruction_queue_tb PASS");
    $finish;
  end

endmodule
