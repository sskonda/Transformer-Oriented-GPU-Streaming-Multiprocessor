class warpforge_ref_model extends uvm_component;
  `uvm_component_utils(warpforge_ref_model)

  uvm_analysis_imp #(warpforge_observation, warpforge_ref_model)
      observation_export;
  uvm_analysis_port #(warpforge_observation) expected_ap;

  instruction_t instruction_memory
      [0:NUM_WARPS-1][0:INSTR_MEM_DEPTH-1];
  logic loaded [0:NUM_WARPS-1][0:INSTR_MEM_DEPTH-1];
  int unsigned pc [0:NUM_WARPS-1];
  scalar_data_t registers [0:NUM_WARPS-1][0:NUM_REGS-1];
  logic register_busy [0:NUM_WARPS-1][0:NUM_REGS-1];
  logic [SHARED_DATA_WIDTH-1:0] tile_words
      [0:NUM_WARPS-1][0:NUM_TILES-1][0:TENSOR_TILE_WORDS-1];
  logic [NUM_WARPS-1:0][NUM_TILES-1:0] tile_valid_model;
  logic prefetch_active;
  warp_id_t prefetch_warp_id;
  tile_id_t prefetch_tile_id;
  int unsigned prefetch_word_index;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    observation_export = new("observation_export", this);
    expected_ap = new("expected_ap", this);
  endfunction

  function void reset_model();
    for (int unsigned warp = 0; warp < NUM_WARPS; warp++) begin
      pc[warp] = 0;
      for (int unsigned reg_index = 0; reg_index < NUM_REGS; reg_index++) begin
        registers[warp][reg_index] = '0;
        register_busy[warp][reg_index] = 1'b0;
      end
    end
    tile_valid_model = '0;
    prefetch_active = 1'b0;
    prefetch_word_index = 0;
  endfunction

  function scalar_data_t calculate_scalar(
    instruction_t instruction,
    warp_id_t warp_id
  );
    logic signed [(2*SCALAR_DATA_WIDTH)-1:0] product;
    logic signed [(2*SCALAR_DATA_WIDTH):0] madd;

    product =
        registers[warp_id][instruction.src0] *
        registers[warp_id][instruction.src1];
    madd =
        product +
        registers[warp_id][instruction.src2];
    unique case (instruction.opcode)
      OP_ALU_ADD: return
          registers[warp_id][instruction.src0] +
          registers[warp_id][instruction.src1];
      OP_ALU_MUL: return product[SCALAR_DATA_WIDTH-1:0];
      OP_ALU_MAD: return madd[SCALAR_DATA_WIDTH-1:0];
      default: return '0;
    endcase
  endfunction

  function void emit_scalar_expected(
    warp_id_t warp_id,
    instruction_t instruction
  );
    warpforge_observation expected;
    expected = warpforge_observation::type_id::create("expected_scalar");
    expected.kind = OBS_SCALAR_RESULT;
    expected.warp_id = warp_id;
    expected.register_index = instruction.dst;
    expected.scalar_data = calculate_scalar(instruction, warp_id);
    expected_ap.write(expected);
  endfunction

  function void emit_tensor_expected(
    warp_id_t warp_id,
    instruction_t instruction
  );
    warpforge_observation expected;
    logic signed [TENSOR_M-1:0][TENSOR_K-1:0]
        [TENSOR_INPUT_WIDTH-1:0] matrix_a;
    logic signed [TENSOR_K-1:0][TENSOR_N-1:0]
        [TENSOR_INPUT_WIDTH-1:0] matrix_b;

    matrix_a = '0;
    matrix_b = '0;
    for (int unsigned row = 0; row < TENSOR_M; row++) begin
      for (int unsigned inner = 0; inner < TENSOR_K; inner++) begin
        int unsigned element;
        int unsigned word_index;
        int unsigned lane;
        element = (row * TENSOR_K) + inner;
        word_index = element / TENSOR_ELEMENTS_PER_WORD;
        lane = element % TENSOR_ELEMENTS_PER_WORD;
        matrix_a[row][inner] = $signed(
          tile_words[warp_id][instruction.tile_id][word_index]
              [(lane*TENSOR_INPUT_WIDTH) +: TENSOR_INPUT_WIDTH]
        );
      end
    end
    for (int unsigned inner = 0; inner < TENSOR_K; inner++) begin
      for (int unsigned col = 0; col < TENSOR_N; col++) begin
        int unsigned element;
        int unsigned word_index;
        int unsigned lane;
        element =
            (TENSOR_M * TENSOR_K) +
            (inner * TENSOR_N) +
            col;
        word_index = element / TENSOR_ELEMENTS_PER_WORD;
        lane = element % TENSOR_ELEMENTS_PER_WORD;
        matrix_b[inner][col] = $signed(
          tile_words[warp_id][instruction.tile_id][word_index]
              [(lane*TENSOR_INPUT_WIDTH) +: TENSOR_INPUT_WIDTH]
        );
      end
    end

    expected = warpforge_observation::type_id::create("expected_tensor");
    expected.kind = OBS_TENSOR_RESULT;
    expected.warp_id = warp_id;
    expected.register_index = instruction.dst;
    expected.tensor_data = '0;
    for (int unsigned row = 0; row < TENSOR_M; row++) begin
      for (int unsigned col = 0; col < TENSOR_N; col++) begin
        for (int unsigned inner = 0; inner < TENSOR_K; inner++) begin
          expected.tensor_data[row][col] +=
              matrix_a[row][inner] * matrix_b[inner][col];
        end
      end
    end
    expected_ap.write(expected);
  endfunction

  function void emit_terminal_expected(
    warpforge_observation_e kind,
    warp_id_t warp_id
  );
    warpforge_observation expected;
    expected = warpforge_observation::type_id::create("expected_terminal");
    expected.kind = kind;
    expected.warp_id = warp_id;
    expected_ap.write(expected);
  endfunction

  function void check_dependencies(
    warp_id_t warp_id,
    instruction_t instruction
  );
    if (
      opcode_uses_src0(instruction.opcode) &&
      register_busy[warp_id][instruction.src0]
    ) begin
      `uvm_error("DEPENDENCY", "Issued with src0 busy")
    end
    if (
      opcode_uses_src1(instruction.opcode) &&
      register_busy[warp_id][instruction.src1]
    ) begin
      `uvm_error("DEPENDENCY", "Issued with src1 busy")
    end
    if (
      opcode_uses_src2(instruction.opcode) &&
      register_busy[warp_id][instruction.src2]
    ) begin
      `uvm_error("DEPENDENCY", "Issued with src2 busy")
    end
  endfunction

  function void process_issue(warpforge_observation observation);
    instruction_t expected_instruction;
    warp_id_t warp_id;

    warp_id = observation.warp_id;
    if (!loaded[warp_id][pc[warp_id]]) begin
      `uvm_error("PROGRAM", "Issued from an unloaded program address")
      return;
    end

    expected_instruction =
        instruction_memory[warp_id][pc[warp_id]];
    if (observation.instruction !== expected_instruction) begin
      `uvm_error(
        "PROGRAM",
        $sformatf(
          "Instruction mismatch warp=%0d pc=%0d expected=%p actual=%p",
          warp_id,
          pc[warp_id],
          expected_instruction,
          observation.instruction
        )
      )
    end

    check_dependencies(warp_id, observation.instruction);

    if (opcode_writes_register(observation.instruction.opcode)) begin
      register_busy[warp_id][observation.instruction.dst] = 1'b1;
    end

    unique case (observation.instruction.opcode)
      OP_ALU_ADD, OP_ALU_MUL, OP_ALU_MAD: begin
        emit_scalar_expected(warp_id, observation.instruction);
        pc[warp_id]++;
      end
      OP_PREFETCH_TILE: begin
        prefetch_active = 1'b1;
        prefetch_warp_id = warp_id;
        prefetch_tile_id = observation.instruction.tile_id;
        prefetch_word_index = 0;
        pc[warp_id]++;
      end
      OP_WAIT_TILE, OP_BARRIER, OP_NOP: pc[warp_id]++;
      OP_TENSOR_MMA: begin
        if (!tile_valid_model[warp_id][observation.instruction.tile_id]) begin
          `uvm_error("TILE", "Tensor instruction issued before tile ready")
        end
        emit_tensor_expected(warp_id, observation.instruction);
        pc[warp_id]++;
      end
      OP_END: emit_terminal_expected(OBS_WARP_DONE, warp_id);
      default: emit_terminal_expected(OBS_WARP_ERROR, warp_id);
    endcase
  endfunction

  function void write(warpforge_observation observation);
    unique case (observation.kind)
      OBS_RESET: begin
        for (int unsigned warp = 0; warp < NUM_WARPS; warp++) begin
          for (
            int unsigned address = 0;
            address < INSTR_MEM_DEPTH;
            address++
          ) begin
            loaded[warp][address] = 1'b0;
          end
        end
        reset_model();
      end
      OBS_CLEAR: reset_model();
      OBS_INSTRUCTION_LOAD: begin
        instruction_memory
            [observation.warp_id][observation.instruction_addr] =
                observation.instruction;
        loaded[observation.warp_id][observation.instruction_addr] = 1'b1;
      end
      OBS_REGISTER_LOAD: begin
        registers[observation.warp_id][observation.register_index] =
            observation.scalar_data;
      end
      OBS_GLOBAL_RESPONSE: begin
        if (!prefetch_active) begin
          `uvm_error("PREFETCH", "Response observed without active prefetch")
        end else begin
          tile_words[prefetch_warp_id][prefetch_tile_id]
              [prefetch_word_index] = observation.memory_data;
          prefetch_word_index++;
          if (prefetch_word_index == TENSOR_TILE_WORDS) begin
            tile_valid_model[prefetch_warp_id][prefetch_tile_id] = 1'b1;
            prefetch_active = 1'b0;
          end
        end
      end
      OBS_ISSUE: process_issue(observation);
      OBS_SCALAR_RESULT: begin
        registers[observation.warp_id][observation.register_index] =
            observation.scalar_data;
        register_busy[observation.warp_id][observation.register_index] =
            1'b0;
      end
      OBS_TENSOR_RESULT: begin
        registers[observation.warp_id][observation.register_index] =
            observation.tensor_data[0][0];
        register_busy[observation.warp_id][observation.register_index] =
            1'b0;
      end
      OBS_DONE: begin
        if (
          observation.counters.completed_warps > NUM_WARPS ||
          observation.counters.tensor_completed >
              observation.counters.tensor_accepted
        ) begin
          `uvm_error("COUNTERS", "Performance counter sanity check failed")
        end
      end
      default: begin
      end
    endcase
  endfunction
endclass
