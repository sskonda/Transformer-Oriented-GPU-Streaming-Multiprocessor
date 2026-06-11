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

    start_program(SCHED_ROUND_ROBIN);
  endtask
endclass
