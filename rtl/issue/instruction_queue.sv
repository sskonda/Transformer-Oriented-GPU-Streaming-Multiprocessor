module instruction_queue #(
  parameter int unsigned NUM_WARPS = warpforge_pkg::NUM_WARPS,
  parameter int unsigned DEPTH = warpforge_pkg::INSTR_MEM_DEPTH,
  parameter int unsigned WARP_ID_WIDTH =
      (NUM_WARPS > 1) ? $clog2(NUM_WARPS) : 1,
  parameter int unsigned ADDR_WIDTH =
      (DEPTH > 1) ? $clog2(DEPTH) : 1
) (
  input  logic clk,
  input  logic rst,
  input  logic clear,

  input  logic load_valid,
  output logic load_ready,
  input  logic [WARP_ID_WIDTH-1:0] load_warp_id,
  input  logic [ADDR_WIDTH-1:0] load_addr,
  input  wire warpforge_pkg::instruction_t load_instruction,

  input  logic issue_valid,
  input  logic issue_accept,
  input  logic [WARP_ID_WIDTH-1:0] issue_warp_id,

  output warpforge_pkg::instruction_t current_instruction [0:NUM_WARPS-1],
  output logic [NUM_WARPS-1:0] instruction_valid,
  output logic [NUM_WARPS-1:0] current_end,
  output logic [NUM_WARPS-1:0] current_illegal,
  output logic [NUM_WARPS-1:0][ADDR_WIDTH-1:0] pc,
  output logic [NUM_WARPS-1:0] halted,
  output logic [NUM_WARPS-1:0] end_issued,
  output logic [NUM_WARPS-1:0] illegal_issued,
  output logic [NUM_WARPS-1:0] pc_error
);
  import warpforge_pkg::*;

  instruction_t instruction_mem [0:NUM_WARPS-1][0:DEPTH-1];
  logic [NUM_WARPS-1:0][DEPTH-1:0] loaded_r;
  logic [NUM_WARPS-1:0][ADDR_WIDTH-1:0] pc_r;
  logic [NUM_WARPS-1:0] halted_r;
  logic [NUM_WARPS-1:0] pc_error_r;
  logic [NUM_WARPS-1:0] end_issued_r;
  logic [NUM_WARPS-1:0] illegal_issued_r;

  always_comb begin
    load_ready =
        !rst &&
        load_warp_id < NUM_WARPS &&
        load_addr < DEPTH;

    for (int unsigned warp = 0; warp < NUM_WARPS; warp++) begin
      current_instruction[warp] = instruction_mem[warp][pc_r[warp]];
      instruction_valid[warp] =
          loaded_r[warp][pc_r[warp]] && !halted_r[warp];
      current_end[warp] =
          instruction_valid[warp] &&
          current_instruction[warp].opcode == OP_END;
      current_illegal[warp] =
          instruction_valid[warp] &&
          !opcode_is_legal(current_instruction[warp].opcode);
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      loaded_r <= '0;
      pc_r <= '0;
      halted_r <= '0;
      pc_error_r <= '0;
      end_issued_r <= '0;
      illegal_issued_r <= '0;
    end else if (clear) begin
      pc_r <= '0;
      halted_r <= '0;
      pc_error_r <= '0;
      end_issued_r <= '0;
      illegal_issued_r <= '0;
    end else begin
      end_issued_r <= '0;
      illegal_issued_r <= '0;

      if (load_valid && load_ready) begin
        instruction_mem[load_warp_id][load_addr] <= load_instruction;
        loaded_r[load_warp_id][load_addr] <= 1'b1;
      end

      if (issue_valid && issue_accept) begin
        if (current_end[issue_warp_id]) begin
          halted_r[issue_warp_id] <= 1'b1;
          end_issued_r[issue_warp_id] <= 1'b1;
        end else if (current_illegal[issue_warp_id]) begin
          halted_r[issue_warp_id] <= 1'b1;
          illegal_issued_r[issue_warp_id] <= 1'b1;
        end else if (pc_r[issue_warp_id] == DEPTH - 1) begin
          halted_r[issue_warp_id] <= 1'b1;
          pc_error_r[issue_warp_id] <= 1'b1;
        end else begin
          pc_r[issue_warp_id] <= pc_r[issue_warp_id] + 1'b1;
        end
      end
    end
  end

  assign pc = pc_r;
  assign halted = halted_r;
  assign end_issued = end_issued_r;
  assign illegal_issued = illegal_issued_r;
  assign pc_error = pc_error_r;

  initial begin
    if (NUM_WARPS == 0 || DEPTH == 0) begin
      $fatal(1, "instruction_queue dimensions must be greater than zero");
    end
  end

`ifndef SYNTHESIS
  instruction_queue_sva #(
    .NUM_WARPS(NUM_WARPS),
    .DEPTH(DEPTH),
    .WARP_ID_WIDTH(WARP_ID_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) assertions (
    .clk,
    .rst,
    .clear,
    .load_valid,
    .load_ready,
    .load_warp_id,
    .load_addr,
    .issue_valid,
    .issue_accept,
    .issue_warp_id,
    .instruction_valid,
    .current_end,
    .current_illegal,
    .pc,
    .end_issued,
    .illegal_issued
  );
`endif

endmodule
