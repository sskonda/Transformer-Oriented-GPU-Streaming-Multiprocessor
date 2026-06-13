`timescale 1ns/1ps

module shared_memory_tb;
  import warpforge_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam int unsigned NUM_PORTS = 2;
  localparam logic [SHARED_ADDR_WIDTH-1:0] BANK0_ROW0 = 0;
  localparam logic [SHARED_ADDR_WIDTH-1:0] BANK1_ROW0 = 1;
  localparam logic [SHARED_ADDR_WIDTH-1:0] BANK0_ROW1 =
      SHARED_ADDR_WIDTH'(SHARED_NUM_BANKS);
  localparam logic [SHARED_DATA_WIDTH-1:0] DATA_A = 32'h1357_9bdf;
  localparam logic [SHARED_DATA_WIDTH-1:0] DATA_B = 32'h2468_ace0;
  localparam logic [SHARED_DATA_WIDTH-1:0] DATA_C = 32'hdead_beef;

  logic clk = 1'b0;
  logic rst;
  logic clear;
  logic [NUM_PORTS-1:0] req_valid;
  logic [NUM_PORTS-1:0] req_ready;
  logic [NUM_PORTS-1:0] req_write;
  logic [NUM_PORTS-1:0][SHARED_ADDR_WIDTH-1:0] req_addr;
  logic [NUM_PORTS-1:0][SHARED_DATA_WIDTH-1:0] req_wdata;
  logic [NUM_PORTS-1:0] rsp_valid;
  logic [NUM_PORTS-1:0][SHARED_DATA_WIDTH-1:0] rsp_rdata;
  logic conflict_event;
  logic [31:0] conflict_count;

  always #(CLK_PERIOD / 2) clk = ~clk;

  shared_memory #(
    .NUM_PORTS(NUM_PORTS)
  ) dut (
    .clk,
    .rst,
    .clear,
    .req_valid,
    .req_ready,
    .req_write,
    .req_addr,
    .req_wdata,
    .rsp_valid,
    .rsp_rdata,
    .conflict_event,
    .conflict_count
  );

  task automatic drive_idle();
    req_valid = '0;
    req_write = '0;
    req_addr = '0;
    req_wdata = '0;
  endtask

  initial begin
    rst = 1'b1;
    clear = 1'b0;
    drive_idle();

    repeat (2) @(negedge clk);
    rst = 1'b0;

    req_valid = '1;
    req_write = '1;
    req_addr[0] = BANK0_ROW0;
    req_addr[1] = BANK1_ROW0;
    req_wdata[0] = DATA_A;
    req_wdata[1] = DATA_B;
    @(negedge clk);
    if (req_ready != '1 || conflict_event) begin
      $fatal(1, "independent-bank writes were not accepted together");
    end

    req_write = '0;
    @(negedge clk);
    drive_idle();
    if (rsp_valid != '1) begin
      $fatal(1, "independent-bank reads did not return together");
    end
    if (rsp_rdata[0] != DATA_A || rsp_rdata[1] != DATA_B) begin
      $fatal(1, "shared-memory readback mismatch");
    end

    req_valid = '1;
    req_write = '1;
    req_addr[0] = BANK0_ROW0;
    req_addr[1] = BANK0_ROW1;
    req_wdata[0] = DATA_A;
    req_wdata[1] = DATA_C;
    @(negedge clk);
    if (req_ready != 2'b01 || !conflict_event) begin
      $fatal(1, "same-bank conflict priority was incorrect");
    end
    if (conflict_count != 1) begin
      $fatal(1, "conflict counter did not count denied request");
    end

    req_valid = 2'b10;
    @(negedge clk);
    if (!req_ready[1]) begin
      $fatal(1, "retried request was not accepted");
    end

    req_write = '0;
    @(negedge clk);
    drive_idle();
    if (!rsp_valid[1] || rsp_rdata[1] != DATA_C) begin
      $fatal(1, "retried request data was not stored");
    end

    clear = 1'b1;
    @(negedge clk);
    clear = 1'b0;
    if (rsp_valid != '0 || conflict_count != '0) begin
      $fatal(1, "clear did not reset shared-memory control state");
    end

    req_valid = 2'b10;
    req_write = '0;
    req_addr[1] = BANK0_ROW1;
    @(negedge clk);
    drive_idle();
    if (!rsp_valid[1] || rsp_rdata[1] != DATA_C) begin
      $fatal(1, "clear unexpectedly modified shared-memory contents");
    end

    $display("shared_memory_tb PASS");
    $finish;
  end

endmodule
