module scalar_register_file #(
  parameter int unsigned NUM_WARPS = warpforge_pkg::NUM_WARPS,
  parameter int unsigned NUM_REGS = warpforge_pkg::NUM_REGS,
  parameter int unsigned DATA_WIDTH = warpforge_pkg::SCALAR_DATA_WIDTH,
  parameter int unsigned WARP_ID_WIDTH =
      (NUM_WARPS > 1) ? $clog2(NUM_WARPS) : 1,
  parameter int unsigned REG_INDEX_WIDTH =
      (NUM_REGS > 1) ? $clog2(NUM_REGS) : 1
) (
  input  logic clk,
  input  logic rst,
  input  logic clear,

  input  logic load_valid,
  input  logic [WARP_ID_WIDTH-1:0] load_warp_id,
  input  logic [REG_INDEX_WIDTH-1:0] load_reg_idx,
  input  logic signed [DATA_WIDTH-1:0] load_data,

  input  logic write_valid,
  input  logic [WARP_ID_WIDTH-1:0] write_warp_id,
  input  logic [REG_INDEX_WIDTH-1:0] write_reg_idx,
  input  logic signed [DATA_WIDTH-1:0] write_data,

  input  logic [WARP_ID_WIDTH-1:0] read_warp_id,
  input  logic [REG_INDEX_WIDTH-1:0] read_src0,
  input  logic [REG_INDEX_WIDTH-1:0] read_src1,
  input  logic [REG_INDEX_WIDTH-1:0] read_src2,
  output logic signed [DATA_WIDTH-1:0] read_data0,
  output logic signed [DATA_WIDTH-1:0] read_data1,
  output logic signed [DATA_WIDTH-1:0] read_data2
);

  logic signed [DATA_WIDTH-1:0] registers
      [0:NUM_WARPS-1][0:NUM_REGS-1];

  always_comb begin
    read_data0 = registers[read_warp_id][read_src0];
    read_data1 = registers[read_warp_id][read_src1];
    read_data2 = registers[read_warp_id][read_src2];
  end

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      for (int unsigned warp = 0; warp < NUM_WARPS; warp++) begin
        for (int unsigned reg_index = 0; reg_index < NUM_REGS; reg_index++) begin
          registers[warp][reg_index] <= '0;
        end
      end
    end else begin
      if (load_valid) begin
        registers[load_warp_id][load_reg_idx] <= load_data;
      end
      if (write_valid) begin
        registers[write_warp_id][write_reg_idx] <= write_data;
      end
    end
  end

  initial begin
    if (NUM_WARPS == 0 || NUM_REGS == 0 || DATA_WIDTH == 0) begin
      $fatal(1, "scalar_register_file parameters must be greater than zero");
    end
  end

endmodule
