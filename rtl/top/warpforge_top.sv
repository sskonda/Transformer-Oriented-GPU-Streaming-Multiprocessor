module warpforge_top #(
  parameter bit ENABLE_OPERAND_FORWARDING = 1'b0,
  parameter warpforge_pkg::tensor_arch_e TENSOR_ARCH =
      warpforge_pkg::TENSOR_ARCH_PIPELINED_TREE
) (
  input  logic clk,
  input  logic rst,
  input  logic clear,
  input  logic start,
  input  warpforge_pkg::scheduler_policy_e scheduler_policy,

  input  logic load_valid,
  output logic load_ready,
  input  warpforge_pkg::warp_id_t load_warp_id,
  input  warpforge_pkg::instr_addr_t load_addr,
  input  wire warpforge_pkg::instruction_t load_instruction,

  input  logic reg_load_valid,
  output logic reg_load_ready,
  input  warpforge_pkg::warp_id_t reg_load_warp_id,
  input  warpforge_pkg::reg_idx_t reg_load_reg_idx,
  input  warpforge_pkg::scalar_data_t reg_load_data,

  output logic global_req_valid,
  input  logic global_req_ready,
  output logic [warpforge_pkg::GLOBAL_ADDR_WIDTH-1:0] global_req_addr,
  input  logic global_rsp_valid,
  output logic global_rsp_ready,
  input  logic [warpforge_pkg::SHARED_DATA_WIDTH-1:0] global_rsp_data,

  output logic busy,
  output logic done,
  output logic issue_valid,
  output warpforge_pkg::warp_id_t issue_warp_id,
  output warpforge_pkg::instruction_t issue_instruction,
  output logic [warpforge_pkg::NUM_WARPS-1:0] warp_done,
  output logic [warpforge_pkg::NUM_WARPS-1:0] warp_error,
  output logic scalar_result_valid,
  output warpforge_pkg::warp_id_t scalar_result_warp_id,
  output warpforge_pkg::reg_idx_t scalar_result_dst,
  output warpforge_pkg::scalar_data_t scalar_result_data,
  output logic tensor_result_valid,
  output warpforge_pkg::warp_id_t tensor_result_warp_id,
  output warpforge_pkg::reg_idx_t tensor_result_dst,
  output logic signed
      [warpforge_pkg::TENSOR_M-1:0]
      [warpforge_pkg::TENSOR_N-1:0]
      [warpforge_pkg::TENSOR_ACC_WIDTH-1:0] tensor_result,
  output logic
      [warpforge_pkg::NUM_WARPS-1:0]
      [warpforge_pkg::NUM_TILES-1:0] tile_valid,
  output warpforge_pkg::perf_counters_t counters
);
  import warpforge_pkg::*;

  localparam int unsigned PREFETCH_LENGTH_WIDTH =
      $clog2(PREFETCH_MAX_TRANSFER_WORDS + 1);
  localparam int unsigned TENSOR_META_DEPTH =
      TENSOR_PIPELINE_LATENCY + 1;
  localparam int unsigned TENSOR_META_LEVEL_WIDTH =
      $clog2(TENSOR_META_DEPTH + 1);
  localparam int unsigned TILE_STORAGE_WORDS =
      NUM_WARPS * NUM_TILES * TENSOR_TILE_WORDS;
  localparam int unsigned SHARED_CONFLICT_COUNTER_WIDTH = 32;
  localparam int unsigned PERF_INCREMENT_WIDTH = 8;
  localparam logic [WARP_ID_WIDTH:0] NUM_WARPS_LIMIT =
      (WARP_ID_WIDTH + 1)'(NUM_WARPS);
  localparam logic [REG_INDEX_WIDTH:0] NUM_REGS_LIMIT =
      (REG_INDEX_WIDTH + 1)'(NUM_REGS);

  typedef struct packed {
    warp_id_t warp_id;
    reg_idx_t dst;
  } tensor_meta_t;

  instruction_t current_instruction [0:NUM_WARPS-1];
  instruction_t selected_instruction;
  logic [NUM_WARPS-1:0] instruction_valid;
  logic [NUM_WARPS-1:0] current_end;
  logic [NUM_WARPS-1:0] current_illegal;
  logic [NUM_WARPS-1:0][INSTR_ADDR_WIDTH-1:0] pc;
  logic [NUM_WARPS-1:0] iq_halted;
  logic [NUM_WARPS-1:0] iq_end_issued;
  logic [NUM_WARPS-1:0] iq_illegal_issued;
  logic [NUM_WARPS-1:0] iq_pc_error;
  logic load_ready_internal;

  logic [NUM_WARPS-1:0][2:0] warp_state;
  logic [NUM_WARPS-1:0] warp_active;
  logic [NUM_WARPS-1:0] warp_waiting;
  logic [NUM_WARPS-1:0] scoreboard_wait;
  logic [NUM_WARPS-1:0] tile_wait;
  logic [NUM_WARPS-1:0] tensor_wait;
  logic [NUM_WARPS-1:0] barrier_wait;
  logic [NUM_WARPS-1:0] prefetch_wait;
  logic [NUM_WARPS-1:0] tile_preferred;
  logic [NUM_WARPS-1:0] warp_done_set;
  logic [NUM_WARPS-1:0] warp_error_set;

  logic scheduler_issue_valid;
  warp_id_t scheduler_warp_id;
  logic [NUM_WARPS-1:0] scheduler_ready;
  warp_id_t round_robin_pointer;
  logic issue_accept;
  logic issue_fire;

  logic [NUM_WARPS-1:0] query_use_src0;
  logic [NUM_WARPS-1:0] query_use_src1;
  logic [NUM_WARPS-1:0] query_use_src2;
  logic [NUM_WARPS-1:0][REG_INDEX_WIDTH-1:0] query_src0;
  logic [NUM_WARPS-1:0][REG_INDEX_WIDTH-1:0] query_src1;
  logic [NUM_WARPS-1:0][REG_INDEX_WIDTH-1:0] query_src2;
  logic [NUM_WARPS-1:0] scoreboard_stall_raw;
  logic [NUM_WARPS-1:0] scoreboard_stall;
  logic [NUM_WARPS-1:0][NUM_REGS-1:0] scoreboard_busy;
  logic scoreboard_set_valid;
  logic scoreboard_clear_valid;

  scalar_data_t register_src0;
  scalar_data_t register_src1;
  scalar_data_t register_src2;
  scalar_data_t scalar_src0;
  scalar_data_t scalar_src1;
  scalar_data_t scalar_src2;
  logic scalar_in_valid;
  logic scalar_in_ready;
  logic scalar_out_valid;
  logic scalar_out_ready;
  scalar_data_t scalar_out_data;
  warp_id_t scalar_out_warp_id;
  reg_idx_t scalar_out_dst;

  logic tensor_in_valid;
  logic tensor_in_ready;
  logic tensor_out_valid;
  logic tensor_out_ready;
  logic tensor_busy;
  logic signed [TENSOR_M-1:0][TENSOR_K-1:0]
      [TENSOR_INPUT_WIDTH-1:0] tensor_matrix_a;
  logic signed [TENSOR_K-1:0][TENSOR_N-1:0]
      [TENSOR_INPUT_WIDTH-1:0] tensor_matrix_b;
  logic signed [TENSOR_M-1:0][TENSOR_N-1:0]
      [TENSOR_ACC_WIDTH-1:0] tensor_matrix_c;
  tensor_meta_t tensor_meta_in;
  tensor_meta_t tensor_meta_out;
  logic [$bits(tensor_meta_t)-1:0] tensor_meta_out_bits;
  logic tensor_meta_in_ready;
  logic tensor_meta_out_valid;
  logic [TENSOR_META_LEVEL_WIDTH-1:0] tensor_meta_level;
  logic tensor_issue_accept;

  logic prefetch_req_valid;
  logic prefetch_req_ready;
  logic [SHARED_ADDR_WIDTH-1:0] prefetch_shared_addr;
  logic [PREFETCH_LENGTH_WIDTH-1:0] prefetch_length;
  logic prefetch_invalidate_valid;
  logic prefetch_shared_wr_valid;
  logic prefetch_shared_wr_ready;
  logic [SHARED_ADDR_WIDTH-1:0] prefetch_shared_wr_addr;
  logic [SHARED_DATA_WIDTH-1:0] prefetch_shared_wr_data;
  logic [$clog2(PREFETCH_QUEUE_DEPTH+1)-1:0] prefetch_queue_level;
  logic prefetch_queue_full;
  logic prefetch_active_valid;
  warp_id_t prefetch_current_warp;
  tile_id_t prefetch_current_tile;
  logic [PREFETCH_LENGTH_WIDTH-1:0] prefetch_word_index;
  logic prefetch_busy;
  logic prefetch_stall;
  logic prefetch_request_accepted;
  logic prefetch_tile_completed;

  logic [0:0] shared_req_valid;
  logic [0:0] shared_req_ready;
  logic [0:0] shared_req_write;
  logic [0:0][SHARED_ADDR_WIDTH-1:0] shared_req_addr;
  logic [0:0][SHARED_DATA_WIDTH-1:0] shared_req_wdata;
  logic [0:0] shared_rsp_valid;
  logic [0:0][SHARED_DATA_WIDTH-1:0] shared_rsp_rdata;
  logic shared_conflict_event;
  logic [SHARED_CONFLICT_COUNTER_WIDTH-1:0] shared_conflict_count;
  logic [PERF_INCREMENT_WIDTH-1:0] bank_conflict_increment;

  logic wb_valid;
  logic wb_tensor_valid;
  logic wb_scalar_valid;
  warp_id_t wb_warp_id;
  reg_idx_t wb_dst;
  scalar_data_t wb_data;

  logic [NUM_WARPS-1:0] launch_mask_r;
  logic launch_pending_r;
  warp_id_t launch_index_r;
  logic start_seen_r;
  logic activate_valid;
  logic all_launched_terminal;
  logic units_busy;

  logic issue_valid_r;
  warp_id_t issue_warp_id_r;
  instruction_t issue_instruction_r;

  instruction_queue instruction_store (
    .clk,
    .rst,
    .clear,
    .load_valid(load_valid && !busy),
    .load_ready(load_ready_internal),
    .load_warp_id,
    .load_addr,
    .load_instruction,
    .issue_valid(scheduler_issue_valid),
    .issue_accept,
    .issue_warp_id(scheduler_warp_id),
    .current_instruction,
    .instruction_valid,
    .current_end,
    .current_illegal,
    .pc,
    .halted(iq_halted),
    .end_issued(iq_end_issued),
    .illegal_issued(iq_illegal_issued),
    .pc_error(iq_pc_error)
  );

  assign load_ready =
      load_ready_internal && !busy && !rst && !clear;
  assign reg_load_ready =
      !busy &&
      !rst &&
      !clear &&
      {1'b0, reg_load_warp_id} < NUM_WARPS_LIMIT &&
      {1'b0, reg_load_reg_idx} < NUM_REGS_LIMIT;

  scalar_register_file register_file (
    .clk,
    .rst,
    .clear,
    .load_valid(reg_load_valid && reg_load_ready),
    .load_warp_id(reg_load_warp_id),
    .load_reg_idx(reg_load_reg_idx),
    .load_data(reg_load_data),
    .write_valid(wb_valid),
    .write_warp_id(wb_warp_id),
    .write_reg_idx(wb_dst),
    .write_data(wb_data),
    .read_warp_id(scheduler_warp_id),
    .read_src0(selected_instruction.src0),
    .read_src1(selected_instruction.src1),
    .read_src2(selected_instruction.src2),
    .read_data0(register_src0),
    .read_data1(register_src1),
    .read_data2(register_src2)
  );

  scoreboard dependency_tracker (
    .clk,
    .rst,
    .clear,
    .set_valid(scoreboard_set_valid),
    .set_warp_id(scheduler_warp_id),
    .set_reg_idx(selected_instruction.dst),
    .clear_valid(scoreboard_clear_valid),
    .clear_warp_id(wb_warp_id),
    .clear_reg_idx(wb_dst),
    .query_use_src0,
    .query_use_src1,
    .query_use_src2,
    .query_src0,
    .query_src1,
    .query_src2,
    .stall(scoreboard_stall_raw),
    .busy(scoreboard_busy)
  );

  warp_state_table state_table (
    .clk,
    .rst,
    .clear,
    .activate_valid,
    .activate_warp_id(launch_index_r),
    .scoreboard_wait,
    .tile_wait,
    .tensor_wait,
    .barrier_wait,
    .done_set(warp_done_set),
    .error_set(warp_error_set),
    .state(warp_state),
    .active(warp_active),
    .done(warp_done),
    .waiting(warp_waiting)
  );

  warp_scheduler scheduler (
    .clk,
    .rst,
    .clear,
    .policy(scheduler_policy),
    .active(warp_active),
    .done(warp_done),
    .instruction_valid,
    .scoreboard_stall,
    .tile_wait,
    .tensor_wait,
    .prefetch_wait,
    .barrier_wait,
    .tile_preferred,
    .issue_accept,
    .issue_valid(scheduler_issue_valid),
    .selected_warp_id(scheduler_warp_id),
    .ready(scheduler_ready),
    .round_robin_pointer
  );

  scalar_alu scalar_unit (
    .clk,
    .rst,
    .clear,
    .in_valid(scalar_in_valid),
    .in_ready(scalar_in_ready),
    .in_opcode(selected_instruction.opcode),
    .in_src0(scalar_src0),
    .in_src1(scalar_src1),
    .in_src2(scalar_src2),
    .in_warp_id(scheduler_warp_id),
    .in_dst(selected_instruction.dst),
    .out_valid(scalar_out_valid),
    .out_ready(scalar_out_ready),
    .out_data(scalar_out_data),
    .out_warp_id(scalar_out_warp_id),
    .out_dst(scalar_out_dst)
  );

  tensor_core #(
    .TENSOR_ARCH(TENSOR_ARCH)
  ) tensor_unit (
    .clk,
    .rst,
    .clear,
    .in_valid(tensor_in_valid),
    .in_ready(tensor_in_ready),
    .matrix_a(tensor_matrix_a),
    .matrix_b(tensor_matrix_b),
    .out_valid(tensor_out_valid),
    .out_ready(tensor_out_ready),
    .matrix_c(tensor_matrix_c),
    .busy(tensor_busy)
  );

  fifo #(
    .WIDTH($bits(tensor_meta_t)),
    .DEPTH(TENSOR_META_DEPTH)
  ) tensor_metadata (
    .clk,
    .rst,
    .clear,
    .in_valid(tensor_issue_accept),
    .in_ready(tensor_meta_in_ready),
    .in_data(tensor_meta_in),
    .out_valid(tensor_meta_out_valid),
    .out_ready(tensor_out_valid && tensor_out_ready),
    .out_data(tensor_meta_out_bits),
    .level(tensor_meta_level)
  );

  assign tensor_meta_out = tensor_meta_t'(tensor_meta_out_bits);

  tensor_tile_buffer tile_buffer (
    .clk,
    .write_valid(
      prefetch_shared_wr_valid &&
      prefetch_shared_wr_ready
    ),
    .write_warp_id(prefetch_current_warp),
    .write_tile_id(prefetch_current_tile),
    .write_word_index(prefetch_word_index),
    .write_data(prefetch_shared_wr_data),
    .read_warp_id(scheduler_warp_id),
    .read_tile_id(selected_instruction.tile_id),
    .matrix_a(tensor_matrix_a),
    .matrix_b(tensor_matrix_b)
  );

  async_tile_prefetch prefetch_unit (
    .clk,
    .rst,
    .clear,
    .req_valid(prefetch_req_valid),
    .req_ready(prefetch_req_ready),
    .req_warp_id(scheduler_warp_id),
    .req_tile_id(selected_instruction.tile_id),
    .req_global_addr(
      GLOBAL_ADDR_WIDTH'(selected_instruction.immediate)
    ),
    .req_shared_addr(prefetch_shared_addr),
    .req_length(prefetch_length),
    .invalidate_valid(prefetch_invalidate_valid),
    .invalidate_warp_id('0),
    .invalidate_tile_id('0),
    .global_req_valid,
    .global_req_ready,
    .global_req_addr,
    .global_rsp_valid,
    .global_rsp_ready,
    .global_rsp_data,
    .shared_wr_valid(prefetch_shared_wr_valid),
    .shared_wr_ready(prefetch_shared_wr_ready),
    .shared_wr_addr(prefetch_shared_wr_addr),
    .shared_wr_data(prefetch_shared_wr_data),
    .tile_valid,
    .queue_level(prefetch_queue_level),
    .queue_full(prefetch_queue_full),
    .active_request_valid(prefetch_active_valid),
    .current_warp_id(prefetch_current_warp),
    .current_tile_id(prefetch_current_tile),
    .current_word_index(prefetch_word_index),
    .prefetch_busy,
    .prefetch_stall,
    .request_accepted(prefetch_request_accepted),
    .tile_completed(prefetch_tile_completed)
  );

  shared_memory #(
    .NUM_PORTS(1),
    .COUNTER_WIDTH(SHARED_CONFLICT_COUNTER_WIDTH)
  ) shared_memory_unit (
    .clk,
    .rst,
    .clear,
    .req_valid(shared_req_valid),
    .req_ready(shared_req_ready),
    .req_write(shared_req_write),
    .req_addr(shared_req_addr),
    .req_wdata(shared_req_wdata),
    .rsp_valid(shared_rsp_valid),
    .rsp_rdata(shared_rsp_rdata),
    .conflict_event(shared_conflict_event),
    .conflict_count(shared_conflict_count)
  );

  assign bank_conflict_increment =
      shared_conflict_event
      ? {{(PERF_INCREMENT_WIDTH-1){1'b0}}, 1'b1}
      : '0;

  perf_counters #(
    .INCREMENT_WIDTH(PERF_INCREMENT_WIDTH)
  ) performance (
    .clk,
    .rst,
    .clear,
    .count_enable(start_seen_r && !done),
    .event_instruction_issued(issue_fire),
    .event_scalar_instruction(
      issue_fire && opcode_is_scalar(selected_instruction.opcode)
    ),
    .event_tensor_instruction(tensor_issue_accept),
    .event_prefetch_instruction(prefetch_request_accepted),
    .event_scheduler_stall(
      start_seen_r && |warp_active && !scheduler_issue_valid
    ),
    .event_scoreboard_stall(|(warp_active & scoreboard_stall)),
    .event_tile_wait(|(warp_active & tile_wait)),
    .event_tensor_wait(|(warp_active & tensor_wait)),
    .event_prefetch_stall_cycle(
      |(warp_active & prefetch_wait) || prefetch_stall
    ),
    .event_tensor_busy(tensor_busy),
    .event_tensor_accepted(tensor_issue_accept),
    .event_tensor_completed(wb_tensor_valid),
    .bank_conflict_increment,
    .event_prefetch_request(prefetch_request_accepted),
    .event_prefetch_stall(prefetch_stall),
    .event_warp_completed(warp_done_set),
    .event_illegal_instruction(
      issue_fire && !opcode_is_legal(selected_instruction.opcode)
    ),
    .counters
  );

  warpforge_issue_control #(
    .ENABLE_OPERAND_FORWARDING(ENABLE_OPERAND_FORWARDING)
  ) issue_control (
    .current_instruction,
    .instruction_valid,
    .warp_active,
    .tile_valid,
    .scoreboard_busy,
    .scoreboard_stall_raw,
    .wb_valid,
    .wb_warp_id,
    .wb_dst,
    .wb_data,
    .register_src0,
    .register_src1,
    .register_src2,
    .scheduler_issue_valid,
    .scheduler_warp_id,
    .scalar_in_ready,
    .tensor_in_ready,
    .tensor_meta_in_ready,
    .prefetch_req_ready,
    .prefetch_queue_full,
    .selected_instruction,
    .query_use_src0,
    .query_use_src1,
    .query_use_src2,
    .query_src0,
    .query_src1,
    .query_src2,
    .scoreboard_stall,
    .scoreboard_wait,
    .tile_wait,
    .tensor_wait,
    .prefetch_wait,
    .tile_preferred,
    .scalar_src0,
    .scalar_src1,
    .scalar_src2,
    .scalar_in_valid,
    .tensor_in_valid,
    .tensor_issue_accept,
    .prefetch_req_valid,
    .issue_accept
  );

  warpforge_run_control run_control (
    .clk,
    .rst,
    .clear,
    .start,
    .busy,
    .instruction_valid,
    .issue_fire,
    .issue_warp_id(scheduler_warp_id),
    .issue_opcode(selected_instruction.opcode),
    .warp_done,
    .warp_error,
    .launch_mask(launch_mask_r),
    .launch_pending(launch_pending_r),
    .launch_index(launch_index_r),
    .start_seen(start_seen_r),
    .activate_valid,
    .barrier_wait
  );

  always_comb begin
    for (int unsigned warp = 0; warp < NUM_WARPS; warp++) begin
      warp_error[warp] = warp_state[warp] == WARP_ERROR;
    end
  end

  always_comb begin
    warp_done_set = '0;
    warp_error_set = iq_pc_error;

    if (issue_fire && selected_instruction.opcode == OP_END) begin
      warp_done_set[scheduler_warp_id] = 1'b1;
    end
    if (
      issue_fire &&
      !opcode_is_legal(selected_instruction.opcode)
    ) begin
      warp_error_set[scheduler_warp_id] = 1'b1;
    end
  end

  assign issue_fire = scheduler_issue_valid && issue_accept;
  assign scoreboard_set_valid =
      issue_fire && opcode_writes_register(selected_instruction.opcode);

  assign wb_tensor_valid = tensor_out_valid && tensor_meta_out_valid;
  assign tensor_out_ready = tensor_meta_out_valid;
  assign scalar_out_ready = !wb_tensor_valid;
  assign wb_scalar_valid = scalar_out_valid && scalar_out_ready;
  assign wb_valid = wb_tensor_valid || wb_scalar_valid;
  assign wb_warp_id =
      wb_tensor_valid ? tensor_meta_out.warp_id : scalar_out_warp_id;
  assign wb_dst = wb_tensor_valid ? tensor_meta_out.dst : scalar_out_dst;
  assign wb_data = wb_tensor_valid
      ? scalar_data_t'(tensor_matrix_c[0][0])
      : scalar_out_data;
  assign scoreboard_clear_valid = wb_valid;

  assign scalar_result_valid = wb_scalar_valid;
  assign scalar_result_warp_id = scalar_out_warp_id;
  assign scalar_result_dst = scalar_out_dst;
  assign scalar_result_data = scalar_out_data;
  assign tensor_result_valid = wb_tensor_valid;
  assign tensor_result_warp_id = tensor_meta_out.warp_id;
  assign tensor_result_dst = tensor_meta_out.dst;
  assign tensor_result = tensor_matrix_c;

  assign tensor_meta_in.warp_id = scheduler_warp_id;
  assign tensor_meta_in.dst = selected_instruction.dst;

  assign prefetch_shared_addr =
      SHARED_ADDR_WIDTH'(
        (
          (int'(scheduler_warp_id) * NUM_TILES) +
          int'(selected_instruction.tile_id)
        ) *
        TENSOR_TILE_WORDS
      );
  assign prefetch_length = PREFETCH_LENGTH_WIDTH'(TENSOR_TILE_WORDS);
  assign prefetch_invalidate_valid = 1'b0;

  assign shared_req_valid[0] = prefetch_shared_wr_valid;
  assign shared_req_write[0] = 1'b1;
  assign shared_req_addr[0] = prefetch_shared_wr_addr;
  assign shared_req_wdata[0] = prefetch_shared_wr_data;
  assign prefetch_shared_wr_ready = shared_req_ready[0];

  always_comb begin
    all_launched_terminal =
        launch_mask_r != '0 &&
        ((warp_done | warp_error) & launch_mask_r) == launch_mask_r;
    units_busy =
        (scoreboard_busy != '0) ||
        tensor_busy ||
        prefetch_busy ||
        scalar_out_valid ||
        tensor_out_valid;
    busy = launch_pending_r || |warp_active || units_busy;
    done = start_seen_r && all_launched_terminal && !units_busy;

  end

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      issue_valid_r <= 1'b0;
      issue_warp_id_r <= '0;
      issue_instruction_r <= '0;
    end else begin
      issue_valid_r <= issue_fire;
      if (issue_fire) begin
        issue_warp_id_r <= scheduler_warp_id;
        issue_instruction_r <= selected_instruction;
      end
    end
  end

  assign issue_valid = issue_valid_r;
  assign issue_warp_id = issue_warp_id_r;
  assign issue_instruction = issue_instruction_r;

  initial begin
    if (NUM_WARPS == 0 || NUM_REGS == 0 || NUM_TILES == 0) begin
      $fatal(1, "warpforge_top dimensions must be greater than zero");
    end
    if (
      SHARED_DATA_WIDTH % TENSOR_INPUT_WIDTH != 0 ||
      TENSOR_TILE_WORDS > PREFETCH_MAX_TRANSFER_WORDS ||
      TILE_STORAGE_WORDS > (1 << SHARED_ADDR_WIDTH)
    ) begin
      $fatal(1, "warpforge_top tile storage configuration is invalid");
    end
  end

`ifndef SYNTHESIS
  top_sva #(
    .NUM_WARPS(NUM_WARPS)
  ) assertions (
    .clk,
    .rst,
    .clear,
    .issue_fire,
    .issue_accept,
    .issue_warp_id(scheduler_warp_id),
    .issue_instruction(selected_instruction),
    .warp_active,
    .warp_done,
    .warp_error,
    .launch_mask(launch_mask_r),
    .busy,
    .done,
    .counters
  );
`endif

endmodule
