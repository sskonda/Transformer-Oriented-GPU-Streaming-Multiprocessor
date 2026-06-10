module skid_buffer #(
  parameter int unsigned WIDTH = 32
) (
  input  logic clk,
  input  logic rst,
  input  logic clear,
  input  logic in_valid,
  output logic in_ready,
  input  logic [WIDTH-1:0] in_data,
  output logic out_valid,
  input  logic out_ready,
  output logic [WIDTH-1:0] out_data
);

  logic valid_r;
  logic [WIDTH-1:0] data_r;

  assign in_ready = !valid_r || out_ready;
  assign out_valid = valid_r;
  assign out_data = data_r;

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      valid_r <= 1'b0;
    end else if (in_ready) begin
      valid_r <= in_valid;
      if (in_valid) begin
        data_r <= in_data;
      end
    end
  end

  initial begin
    if (WIDTH == 0) begin
      $fatal(1, "skid_buffer WIDTH must be greater than zero");
    end
  end

`ifndef SYNTHESIS
  assert property (@(posedge clk) disable iff (rst || clear)
    out_valid && !out_ready |=> out_valid && $stable(out_data));
`endif

endmodule
