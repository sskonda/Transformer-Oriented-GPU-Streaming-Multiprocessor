module ram_sdp #(
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned ADDR_WIDTH = 8
) (
  input  logic clk,
  input  logic rst,
  input  logic rd_en,
  input  logic [ADDR_WIDTH-1:0] rd_addr,
  output logic rd_valid,
  output logic [DATA_WIDTH-1:0] rd_data,
  input  logic wr_en,
  input  logic [ADDR_WIDTH-1:0] wr_addr,
  input  logic [DATA_WIDTH-1:0] wr_data
);

  logic [DATA_WIDTH-1:0] mem [0:(1 << ADDR_WIDTH)-1];

  always_ff @(posedge clk) begin
    if (wr_en) begin
      mem[wr_addr] <= wr_data;
    end

    if (rd_en) begin
      rd_data <= mem[rd_addr];
    end

    if (rst) begin
      rd_valid <= 1'b0;
    end else begin
      rd_valid <= rd_en;
    end
  end

  initial begin
    if (DATA_WIDTH == 0 || ADDR_WIDTH == 0) begin
      $fatal(1, "ram_sdp parameters must be greater than zero");
    end
  end

`ifndef SYNTHESIS
  assert property (@(posedge clk) rd_en |-> !$isunknown(rd_addr));
  assert property (@(posedge clk) wr_en |-> !$isunknown(wr_addr));
`endif

endmodule
