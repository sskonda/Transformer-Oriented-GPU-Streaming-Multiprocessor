module warpforge_issue_control #(
  parameter bit ENABLE_OPERAND_FORWARDING = 1'b0
) (
  input  wire warpforge_pkg::instruction_t current_instruction
      [0:warpforge_pkg::NUM_WARPS-1],
  input  logic [warpforge_pkg::NUM_WARPS-1:0] instruction_valid,
  input  logic [warpforge_pkg::NUM_WARPS-1:0] warp_active,
  input  wire logic
      [warpforge_pkg::NUM_WARPS-1:0]
      [warpforge_pkg::NUM_TILES-1:0] tile_valid,
  input  wire logic
      [warpforge_pkg::NUM_WARPS-1:0]
      [warpforge_pkg::NUM_REGS-1:0] scoreboard_busy,
  input  logic [warpforge_pkg::NUM_WARPS-1:0] scoreboard_stall_raw,
  input  logic wb_valid,
  input  warpforge_pkg::warp_id_t wb_warp_id,
  input  warpforge_pkg::reg_idx_t wb_dst,
  input  warpforge_pkg::scalar_data_t wb_data,
  input  warpforge_pkg::scalar_data_t register_src0,
  input  warpforge_pkg::scalar_data_t register_src1,
  input  warpforge_pkg::scalar_data_t register_src2,
  input  logic scheduler_issue_valid,
  input  warpforge_pkg::warp_id_t scheduler_warp_id,
  input  logic scalar_in_ready,
  input  logic tensor_in_ready,
  input  logic tensor_meta_in_ready,
  input  logic prefetch_req_ready,
  input  logic prefetch_queue_full,

  output warpforge_pkg::instruction_t selected_instruction,
  output logic [warpforge_pkg::NUM_WARPS-1:0] query_use_src0,
  output logic [warpforge_pkg::NUM_WARPS-1:0] query_use_src1,
  output logic [warpforge_pkg::NUM_WARPS-1:0] query_use_src2,
  output logic
      [warpforge_pkg::NUM_WARPS-1:0]
      [warpforge_pkg::REG_INDEX_WIDTH-1:0] query_src0,
  output logic
      [warpforge_pkg::NUM_WARPS-1:0]
      [warpforge_pkg::REG_INDEX_WIDTH-1:0] query_src1,
  output logic
      [warpforge_pkg::NUM_WARPS-1:0]
      [warpforge_pkg::REG_INDEX_WIDTH-1:0] query_src2,
  output logic [warpforge_pkg::NUM_WARPS-1:0] scoreboard_stall,
  output logic [warpforge_pkg::NUM_WARPS-1:0] scoreboard_wait,
  output logic [warpforge_pkg::NUM_WARPS-1:0] tile_wait,
  output logic [warpforge_pkg::NUM_WARPS-1:0] tensor_wait,
  output logic [warpforge_pkg::NUM_WARPS-1:0] prefetch_wait,
  output logic [warpforge_pkg::NUM_WARPS-1:0] tile_preferred,
  output warpforge_pkg::scalar_data_t scalar_src0,
  output warpforge_pkg::scalar_data_t scalar_src1,
  output warpforge_pkg::scalar_data_t scalar_src2,
  output logic scalar_in_valid,
  output logic tensor_in_valid,
  output logic tensor_issue_accept,
  output logic prefetch_req_valid,
  output logic issue_accept
);
  import warpforge_pkg::*;

  function automatic logic source_blocked(
    input int unsigned warp,
    input logic source_used,
    input reg_idx_t source
  );
    logic forwarding_match;

    forwarding_match =
        ENABLE_OPERAND_FORWARDING &&
        wb_valid &&
        wb_warp_id == warp &&
        wb_dst == source;
    return source_used &&
        scoreboard_busy[warp][source] &&
        !forwarding_match;
  endfunction

  always_comb begin
    selected_instruction = '0;
    if (scheduler_issue_valid) begin
      selected_instruction = current_instruction[scheduler_warp_id];
    end

    for (int unsigned warp = 0; warp < NUM_WARPS; warp++) begin
      query_use_src0[warp] =
          instruction_valid[warp] &&
          opcode_uses_src0(current_instruction[warp].opcode);
      query_use_src1[warp] =
          instruction_valid[warp] &&
          opcode_uses_src1(current_instruction[warp].opcode);
      query_use_src2[warp] =
          instruction_valid[warp] &&
          opcode_uses_src2(current_instruction[warp].opcode);
      query_src0[warp] = current_instruction[warp].src0;
      query_src1[warp] = current_instruction[warp].src1;
      query_src2[warp] = current_instruction[warp].src2;

      if (ENABLE_OPERAND_FORWARDING) begin
        scoreboard_stall[warp] =
            source_blocked(warp, query_use_src0[warp], query_src0[warp]) ||
            source_blocked(warp, query_use_src1[warp], query_src1[warp]) ||
            source_blocked(warp, query_use_src2[warp], query_src2[warp]);
      end else begin
        scoreboard_stall[warp] = scoreboard_stall_raw[warp];
      end

      scoreboard_stall[warp] =
          scoreboard_stall[warp] ||
          (
            instruction_valid[warp] &&
            opcode_writes_register(current_instruction[warp].opcode) &&
            scoreboard_busy[warp][current_instruction[warp].dst]
          );
      scoreboard_wait[warp] =
          warp_active[warp] && scoreboard_stall[warp];
      tile_wait[warp] =
          warp_active[warp] &&
          instruction_valid[warp] &&
          current_instruction[warp].opcode inside {
            OP_WAIT_TILE,
            OP_TENSOR_MMA
          } &&
          !tile_valid[warp][current_instruction[warp].tile_id];
      tensor_wait[warp] =
          warp_active[warp] &&
          instruction_valid[warp] &&
          current_instruction[warp].opcode == OP_TENSOR_MMA &&
          (!tensor_in_ready || !tensor_meta_in_ready);
      prefetch_wait[warp] =
          warp_active[warp] &&
          instruction_valid[warp] &&
          current_instruction[warp].opcode == OP_PREFETCH_TILE &&
          prefetch_queue_full;
      tile_preferred[warp] =
          warp_active[warp] &&
          instruction_valid[warp] &&
          current_instruction[warp].opcode == OP_TENSOR_MMA &&
          tile_valid[warp][current_instruction[warp].tile_id];
    end
  end

  always_comb begin
    scalar_src0 = register_src0;
    scalar_src1 = register_src1;
    scalar_src2 = register_src2;

    if (
      ENABLE_OPERAND_FORWARDING &&
      wb_valid &&
      wb_warp_id == scheduler_warp_id
    ) begin
      if (wb_dst == selected_instruction.src0) begin
        scalar_src0 = wb_data;
      end
      if (wb_dst == selected_instruction.src1) begin
        scalar_src1 = wb_data;
      end
      if (wb_dst == selected_instruction.src2) begin
        scalar_src2 = wb_data;
      end
    end
  end

  always_comb begin
    issue_accept = 1'b0;
    scalar_in_valid = 1'b0;
    tensor_in_valid = 1'b0;
    tensor_issue_accept = 1'b0;
    prefetch_req_valid = 1'b0;

    if (scheduler_issue_valid) begin
      unique case (selected_instruction.opcode)
        OP_NOP, OP_WAIT_TILE, OP_BARRIER, OP_END: begin
          issue_accept = 1'b1;
        end

        OP_ALU_ADD, OP_ALU_MUL, OP_ALU_MAD: begin
          scalar_in_valid = 1'b1;
          issue_accept = scalar_in_ready;
        end

        OP_TENSOR_MMA: begin
          tensor_in_valid =
              tensor_meta_in_ready &&
              tile_valid[scheduler_warp_id][selected_instruction.tile_id];
          tensor_issue_accept = tensor_in_valid && tensor_in_ready;
          issue_accept = tensor_issue_accept;
        end

        OP_PREFETCH_TILE: begin
          prefetch_req_valid = 1'b1;
          issue_accept = prefetch_req_ready;
        end

        default: begin
          issue_accept = 1'b1;
        end
      endcase
    end
  end

endmodule
