class warpforge_base_sequence extends uvm_sequence #(warpforge_seq_item);
  `uvm_object_utils(warpforge_base_sequence)

  function new(string name = "warpforge_base_sequence");
    super.new(name);
  endfunction

  task send_item(warpforge_seq_item item);
    start_item(item);
    finish_item(item);
  endtask

  task load_memory_word(
    logic [GLOBAL_ADDR_WIDTH-1:0] address,
    logic [SHARED_DATA_WIDTH-1:0] data
  );
    warpforge_seq_item item;
    item = warpforge_seq_item::type_id::create("memory_item");
    item.command = CMD_LOAD_MEMORY;
    item.memory_addr = address;
    item.memory_data = data;
    send_item(item);
  endtask

  task load_register_value(
    warp_id_t warp_id,
    reg_idx_t register_index,
    scalar_data_t data
  );
    warpforge_seq_item item;
    item = warpforge_seq_item::type_id::create("register_item");
    item.command = CMD_LOAD_REGISTER;
    item.warp_id = warp_id;
    item.register_index = register_index;
    item.register_data = data;
    send_item(item);
  endtask

  task load_program_instruction(
    warp_id_t warp_id,
    instr_addr_t address,
    opcode_e opcode,
    reg_idx_t dst,
    reg_idx_t src0,
    reg_idx_t src1,
    reg_idx_t src2,
    tile_id_t tile_id,
    logic [15:0] immediate
  );
    warpforge_seq_item item;
    item = warpforge_seq_item::type_id::create("instruction_item");
    item.command = CMD_LOAD_INSTRUCTION;
    item.warp_id = warp_id;
    item.instruction_addr = address;
    item.instruction = '0;
    item.instruction.opcode = opcode;
    item.instruction.dst = dst;
    item.instruction.src0 = src0;
    item.instruction.src1 = src1;
    item.instruction.src2 = src2;
    item.instruction.tile_id = tile_id;
    item.instruction.immediate = immediate;
    send_item(item);
  endtask

  task start_program(scheduler_policy_e policy);
    warpforge_seq_item item;
    item = warpforge_seq_item::type_id::create("start_item");
    item.command = CMD_START;
    item.scheduler_policy = policy;
    send_item(item);
  endtask
endclass

class warpforge_smoke_sequence extends warpforge_base_sequence;
  `uvm_object_utils(warpforge_smoke_sequence)

  scheduler_policy_e policy = SCHED_ROUND_ROBIN;

  function new(string name = "warpforge_smoke_sequence");
    super.new(name);
  endfunction

  task body();
    load_memory_word(0, 32'h0403_0201);
    load_memory_word(1, 32'h0807_0605);
    load_memory_word(2, 32'h0c0b_0a09);
    load_memory_word(3, 32'h100f_0e0d);
    load_memory_word(4, 32'h0000_0001);
    load_memory_word(5, 32'h0000_0100);
    load_memory_word(6, 32'h0001_0000);
    load_memory_word(7, 32'h0100_0000);

    load_program_instruction(
      0, 0, OP_PREFETCH_TILE, 0, 0, 0, 0, 0, 0
    );
    load_program_instruction(
      0, 1, OP_WAIT_TILE, 0, 0, 0, 0, 0, 0
    );
    load_program_instruction(
      0, 2, OP_TENSOR_MMA, 0, 0, 0, 0, 0, 0
    );
    load_program_instruction(
      0, 3, OP_END, 0, 0, 0, 0, 0, 0
    );

    load_register_value(1, 1, 2);
    load_register_value(1, 2, 3);
    load_register_value(1, 3, 4);
    load_program_instruction(
      1, 0, OP_ALU_ADD, 4, 1, 2, 0, 0, 0
    );
    load_program_instruction(
      1, 1, OP_ALU_MAD, 5, 4, 2, 3, 0, 0
    );
    load_program_instruction(
      1, 2, OP_END, 0, 0, 0, 0, 0, 0
    );

    start_program(policy);
  endtask
endclass

class warpforge_single_gemm_sequence extends warpforge_base_sequence;
  `uvm_object_utils(warpforge_single_gemm_sequence)

  scheduler_policy_e policy = SCHED_ROUND_ROBIN;

  function new(string name = "warpforge_single_gemm_sequence");
    super.new(name);
  endfunction

  task body();
    load_memory_word(0, 32'h0403_0201);
    load_memory_word(1, 32'h0807_0605);
    load_memory_word(2, 32'h0c0b_0a09);
    load_memory_word(3, 32'h100f_0e0d);
    load_memory_word(4, 32'h0000_0001);
    load_memory_word(5, 32'h0000_0100);
    load_memory_word(6, 32'h0001_0000);
    load_memory_word(7, 32'h0100_0000);
    load_program_instruction(
      0, 0, OP_PREFETCH_TILE, 0, 0, 0, 0, 0, 0
    );
    load_program_instruction(
      0, 1, OP_WAIT_TILE, 0, 0, 0, 0, 0, 0
    );
    load_program_instruction(
      0, 2, OP_TENSOR_MMA, 0, 0, 0, 0, 0, 0
    );
    load_program_instruction(
      0, 3, OP_END, 0, 0, 0, 0, 0, 0
    );
    start_program(policy);
  endtask
endclass

class warpforge_illegal_sequence extends warpforge_base_sequence;
  `uvm_object_utils(warpforge_illegal_sequence)

  function new(string name = "warpforge_illegal_sequence");
    super.new(name);
  endfunction

  task body();
    load_program_instruction(
      0, 0, OP_ILLEGAL, 0, 0, 0, 0, 0, 0
    );
    start_program(SCHED_ROUND_ROBIN);
  endtask
endclass

class warpforge_barrier_sequence extends warpforge_base_sequence;
  `uvm_object_utils(warpforge_barrier_sequence)

  function new(string name = "warpforge_barrier_sequence");
    super.new(name);
  endfunction

  task body();
    for (int unsigned warp = 0; warp < 2; warp++) begin
      load_program_instruction(
        warp_id_t'(warp), 0, OP_BARRIER, 0, 0, 0, 0, 0, 0
      );
      load_program_instruction(
        warp_id_t'(warp), 1, OP_END, 0, 0, 0, 0, 0, 0
      );
    end
    start_program(SCHED_ROUND_ROBIN);
  endtask
endclass

class warpforge_reset_recovery_sequence extends warpforge_base_sequence;
  `uvm_object_utils(warpforge_reset_recovery_sequence)

  function new(string name = "warpforge_reset_recovery_sequence");
    super.new(name);
  endfunction

  task wait_cycles(int unsigned cycles);
    warpforge_seq_item item;
    item = warpforge_seq_item::type_id::create("wait_item");
    item.command = CMD_WAIT_CYCLES;
    item.wait_cycles = cycles;
    send_item(item);
  endtask

  task clear_dut();
    warpforge_seq_item item;
    item = warpforge_seq_item::type_id::create("clear_item");
    item.command = CMD_CLEAR;
    send_item(item);
  endtask

  task body();
    load_memory_word(0, 32'h0403_0201);
    load_memory_word(1, 32'h0807_0605);
    load_memory_word(2, 32'h0c0b_0a09);
    load_memory_word(3, 32'h100f_0e0d);
    load_memory_word(4, 32'h0000_0001);
    load_memory_word(5, 32'h0000_0100);
    load_memory_word(6, 32'h0001_0000);
    load_memory_word(7, 32'h0100_0000);
    load_program_instruction(
      0, 0, OP_PREFETCH_TILE, 0, 0, 0, 0, 0, 0
    );
    load_program_instruction(
      0, 1, OP_WAIT_TILE, 0, 0, 0, 0, 0, 0
    );
    load_program_instruction(
      0, 2, OP_TENSOR_MMA, 0, 0, 0, 0, 0, 0
    );
    load_program_instruction(
      0, 3, OP_END, 0, 0, 0, 0, 0, 0
    );
    start_program(SCHED_ROUND_ROBIN);
    wait_cycles(6);
    clear_dut();
    wait_cycles(2);
    start_program(SCHED_ROUND_ROBIN);
  endtask
endclass

class warpforge_random_instruction extends uvm_object;
  `uvm_object_utils(warpforge_random_instruction)

`ifdef WARPFORGE_ENABLE_CONSTRAINED_RANDOM
  rand opcode_e opcode;
  constraint scalar_opcode_c {
    opcode inside {OP_ALU_ADD, OP_ALU_MUL, OP_ALU_MAD};
  }
`else
  opcode_e opcode;
`endif

  function new(string name = "warpforge_random_instruction");
    super.new(name);
  endfunction
endclass

class warpforge_random_scalar_sequence extends warpforge_base_sequence;
  `uvm_object_utils(warpforge_random_scalar_sequence)

  int unsigned warp_count = 2;
  int unsigned instructions_per_warp = 8;
  scheduler_policy_e policy = SCHED_ROUND_ROBIN;

  function new(string name = "warpforge_random_scalar_sequence");
    super.new(name);
  endfunction

  function automatic logic [31:0] next_lfsr(logic [31:0] state);
    return {state[30:0], state[31] ^ state[21] ^ state[1] ^ state[0]};
  endfunction

  task body();
    int unsigned seed;
    logic [31:0] lfsr;
    warpforge_random_instruction random_instruction;

    seed = 1;
    void'($value$plusargs("SEED=%d", seed));
    lfsr = seed;
    `uvm_info("SEED", $sformatf("WarpForge seed=%0d", seed), UVM_LOW)

    for (int unsigned warp = 0; warp < warp_count; warp++) begin
      load_register_value(warp_id_t'(warp), 1, scalar_data_t'(warp + 2));
      load_register_value(warp_id_t'(warp), 2, 3);
      load_register_value(warp_id_t'(warp), 3, 4);

      for (
        int unsigned address = 0;
        address < instructions_per_warp;
        address++
      ) begin
        opcode_e opcode;
        random_instruction =
            warpforge_random_instruction::type_id::create(
              $sformatf("random_instruction_%0d_%0d", warp, address)
            );
`ifdef WARPFORGE_ENABLE_CONSTRAINED_RANDOM
        random_instruction.srandom(seed + (warp * 256) + address);
        if (!random_instruction.randomize()) begin
          `uvm_fatal("RANDOMIZE", "Scalar opcode randomization failed")
        end
        opcode = random_instruction.opcode;
`else
        lfsr = next_lfsr(lfsr);
        unique case (lfsr[1:0])
          2'd0: opcode = OP_ALU_ADD;
          2'd1: opcode = OP_ALU_MUL;
          default: opcode = OP_ALU_MAD;
        endcase
`endif
        load_program_instruction(
          warp_id_t'(warp),
          instr_addr_t'(address),
          opcode,
          reg_idx_t'(4 + address),
          1,
          2,
          3,
          0,
          0
        );
      end
      load_program_instruction(
        warp_id_t'(warp),
        instr_addr_t'(instructions_per_warp),
        OP_END,
        0,
        0,
        0,
        0,
        0,
        0
      );
    end
    start_program(policy);
  endtask
endclass
