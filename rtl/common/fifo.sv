module fifo #(
  parameter int unsigned WIDTH = 32,
  parameter int unsigned DEPTH = 4
) (
  input  logic clk,
  input  logic rst,
  input  logic clear,
  input  logic in_valid,
  output logic in_ready,
  input  logic [WIDTH-1:0] in_data,
  output logic out_valid,
  input  logic out_ready,
  output logic [WIDTH-1:0] out_data,
  output logic [$clog2(DEPTH+1)-1:0] level
);

  localparam int unsigned PTR_WIDTH = (DEPTH > 1) ? $clog2(DEPTH) : 1;
  localparam int unsigned COUNT_WIDTH = $clog2(DEPTH + 1);
  localparam logic [PTR_WIDTH-1:0] LAST_PTR = PTR_WIDTH'(DEPTH - 1);
  localparam logic [COUNT_WIDTH-1:0] DEPTH_COUNT = COUNT_WIDTH'(DEPTH);

  logic [WIDTH-1:0] mem [0:DEPTH-1];
  logic [PTR_WIDTH-1:0] rd_ptr_r;
  logic [PTR_WIDTH-1:0] wr_ptr_r;
  logic [COUNT_WIDTH-1:0] count_r;
  logic push;
  logic pop;

  function automatic logic [PTR_WIDTH-1:0] next_ptr(
    input logic [PTR_WIDTH-1:0] ptr
  );
    return (ptr == LAST_PTR) ? '0 : ptr + 1'b1;
  endfunction

  assign out_valid = count_r != '0;
  assign out_data = mem[rd_ptr_r];
  assign in_ready = (count_r != DEPTH_COUNT) || (out_valid && out_ready);
  assign push = in_valid && in_ready;
  assign pop = out_valid && out_ready;
  assign level = count_r;

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      rd_ptr_r <= '0;
      wr_ptr_r <= '0;
      count_r <= '0;
    end else begin
      if (push) begin
        mem[wr_ptr_r] <= in_data;
        wr_ptr_r <= next_ptr(wr_ptr_r);
      end

      if (pop) begin
        rd_ptr_r <= next_ptr(rd_ptr_r);
      end

      unique case ({push, pop})
        2'b10: count_r <= count_r + 1'b1;
        2'b01: count_r <= count_r - 1'b1;
        default: count_r <= count_r;
      endcase
    end
  end

  initial begin
    if (WIDTH == 0 || DEPTH == 0) begin
      $fatal(1, "fifo parameters must be greater than zero");
    end
  end

`ifndef SYNTHESIS
  assert property (@(posedge clk) disable iff (rst || clear)
    count_r <= DEPTH_COUNT);
  assert property (@(posedge clk) disable iff (rst || clear)
    in_valid && !in_ready |-> !push);
  assert property (@(posedge clk) disable iff (rst || clear)
    out_ready && !out_valid |-> !pop);
`endif

endmodule
