module scalar_alu #(
  parameter int unsigned DATA_WIDTH = warpforge_pkg::SCALAR_DATA_WIDTH,
  parameter int unsigned LATENCY = 1,
  parameter int unsigned WARP_ID_WIDTH = warpforge_pkg::WARP_ID_WIDTH,
  parameter int unsigned REG_INDEX_WIDTH = warpforge_pkg::REG_INDEX_WIDTH
) (
  input  logic clk,
  input  logic rst,
  input  logic clear,

  input  logic in_valid,
  output logic in_ready,
  input  warpforge_pkg::opcode_e in_opcode,
  input  logic signed [DATA_WIDTH-1:0] in_src0,
  input  logic signed [DATA_WIDTH-1:0] in_src1,
  input  logic signed [DATA_WIDTH-1:0] in_src2,
  input  logic [WARP_ID_WIDTH-1:0] in_warp_id,
  input  logic [REG_INDEX_WIDTH-1:0] in_dst,

  output logic out_valid,
  input  logic out_ready,
  output logic signed [DATA_WIDTH-1:0] out_data,
  output logic [WARP_ID_WIDTH-1:0] out_warp_id,
  output logic [REG_INDEX_WIDTH-1:0] out_dst
);
  import warpforge_pkg::*;

  typedef struct packed {
    logic signed [DATA_WIDTH-1:0] data;
    logic [WARP_ID_WIDTH-1:0] warp_id;
    logic [REG_INDEX_WIDTH-1:0] dst;
  } scalar_payload_t;

  function automatic logic signed [DATA_WIDTH-1:0] calculate_result(
    input opcode_e opcode,
    input logic signed [DATA_WIDTH-1:0] src0,
    input logic signed [DATA_WIDTH-1:0] src1,
    input logic signed [DATA_WIDTH-1:0] src2
  );
    logic signed [(2*DATA_WIDTH)-1:0] product;
    logic signed [(2*DATA_WIDTH)-1:0] addend;
    logic signed [(2*DATA_WIDTH):0] madd;

    product = src0 * src1;
    addend = {{DATA_WIDTH{src2[DATA_WIDTH-1]}}, src2};
    madd = product + addend;

    unique case (opcode)
      OP_ALU_ADD: calculate_result = src0 + src1;
      OP_ALU_MUL: calculate_result = product[DATA_WIDTH-1:0];
      OP_ALU_MAD: calculate_result = madd[DATA_WIDTH-1:0];
      default: calculate_result = '0;
    endcase
  endfunction

  generate
    if (LATENCY == 0) begin : g_bypass
      logic legal_operation;

      assign legal_operation = opcode_is_scalar(in_opcode);
      assign in_ready = out_ready && (!in_valid || legal_operation);
      assign out_valid = in_valid && legal_operation;
      assign out_data =
          calculate_result(in_opcode, in_src0, in_src1, in_src2);
      assign out_warp_id = in_warp_id;
      assign out_dst = in_dst;
    end else begin : g_pipeline
      logic [LATENCY-1:0] valid_r;
      logic [LATENCY-1:0] stage_ready;
      scalar_payload_t payload_r [0:LATENCY-1];

      always_comb begin
        stage_ready = '0;
        stage_ready[LATENCY-1] =
            !valid_r[LATENCY-1] || out_ready;
        for (int stage = LATENCY - 2; stage >= 0; stage--) begin
          stage_ready[stage] =
              !valid_r[stage] || stage_ready[stage+1];
        end
      end

      assign in_ready =
          stage_ready[0] &&
          (!in_valid || opcode_is_scalar(in_opcode));
      assign out_valid = valid_r[LATENCY-1];
      assign out_data = payload_r[LATENCY-1].data;
      assign out_warp_id = payload_r[LATENCY-1].warp_id;
      assign out_dst = payload_r[LATENCY-1].dst;

      always_ff @(posedge clk) begin
        if (rst || clear) begin
          valid_r <= '0;
        end else begin
          for (int stage = LATENCY - 1; stage > 0; stage--) begin
            if (stage_ready[stage]) begin
              valid_r[stage] <= valid_r[stage-1];
              if (valid_r[stage-1]) begin
                payload_r[stage] <= payload_r[stage-1];
              end
            end
          end

          if (stage_ready[0]) begin
            valid_r[0] <= in_valid && opcode_is_scalar(in_opcode);
            if (in_valid && opcode_is_scalar(in_opcode)) begin
              payload_r[0].data <=
                  calculate_result(in_opcode, in_src0, in_src1, in_src2);
              payload_r[0].warp_id <= in_warp_id;
              payload_r[0].dst <= in_dst;
            end
          end
        end
      end
    end
  endgenerate

  initial begin
    if (DATA_WIDTH == 0) begin
      $fatal(1, "scalar_alu DATA_WIDTH must be greater than zero");
    end
  end

`ifndef SYNTHESIS
  scalar_alu_sva #(
    .DATA_WIDTH(DATA_WIDTH),
    .WARP_ID_WIDTH(WARP_ID_WIDTH),
    .REG_INDEX_WIDTH(REG_INDEX_WIDTH)
  ) assertions (
    .clk,
    .rst,
    .clear,
    .in_valid,
    .in_ready,
    .in_opcode,
    .out_valid,
    .out_ready,
    .out_data,
    .out_warp_id,
    .out_dst
  );
`endif

endmodule
