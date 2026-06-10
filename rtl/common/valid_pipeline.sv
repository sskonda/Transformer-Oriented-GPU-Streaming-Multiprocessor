module valid_pipeline #(
  parameter int unsigned WIDTH = 32,
  parameter int unsigned LATENCY = 1
) (
  input  logic clk,
  input  logic rst,
  input  logic clear,
  input  logic in_valid,
  input  logic [WIDTH-1:0] in_data,
  output logic out_valid,
  output logic [WIDTH-1:0] out_data
);

  generate
    if (LATENCY == 0) begin : g_bypass
      assign out_valid = in_valid;
      assign out_data = in_data;
    end else begin : g_pipeline
      logic [LATENCY-1:0] valid_r;
      logic [LATENCY-1:0][WIDTH-1:0] data_r;

      always_ff @(posedge clk) begin
        if (rst || clear) begin
          valid_r <= '0;
        end else begin
          valid_r[0] <= in_valid;
          if (in_valid) begin
            data_r[0] <= in_data;
          end

          for (int unsigned stage = 1; stage < LATENCY; stage++) begin
            valid_r[stage] <= valid_r[stage-1];
            if (valid_r[stage-1]) begin
              data_r[stage] <= data_r[stage-1];
            end
          end
        end
      end

      assign out_valid = valid_r[LATENCY-1];
      assign out_data = data_r[LATENCY-1];
    end
  endgenerate

  initial begin
    if (WIDTH == 0) begin
      $fatal(1, "valid_pipeline WIDTH must be greater than zero");
    end
  end

endmodule
