typedef enum logic [2:0] {
  CMD_LOAD_INSTRUCTION,
  CMD_LOAD_REGISTER,
  CMD_LOAD_MEMORY,
  CMD_START,
  CMD_CLEAR
} warpforge_cmd_e;

typedef enum logic [3:0] {
  OBS_RESET,
  OBS_CLEAR,
  OBS_INSTRUCTION_LOAD,
  OBS_REGISTER_LOAD,
  OBS_GLOBAL_REQUEST,
  OBS_GLOBAL_RESPONSE,
  OBS_ISSUE,
  OBS_SCALAR_RESULT,
  OBS_TENSOR_RESULT,
  OBS_WARP_DONE,
  OBS_WARP_ERROR,
  OBS_DONE
} warpforge_observation_e;

class warpforge_seq_item extends uvm_sequence_item;
  warpforge_cmd_e command;
  warp_id_t warp_id;
  instr_addr_t instruction_addr;
  reg_idx_t register_index;
  scalar_data_t register_data;
  logic [GLOBAL_ADDR_WIDTH-1:0] memory_addr;
  logic [SHARED_DATA_WIDTH-1:0] memory_data;
  scheduler_policy_e scheduler_policy;
  instruction_t instruction;

  `uvm_object_utils(warpforge_seq_item)

  function new(string name = "warpforge_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf(
      "command=%s warp=%0d addr=%0d opcode=%s",
      command.name(),
      warp_id,
      instruction_addr,
      instruction.opcode.name()
    );
  endfunction
endclass

class warpforge_observation extends uvm_sequence_item;
  warpforge_observation_e kind;
  warp_id_t warp_id;
  instr_addr_t instruction_addr;
  reg_idx_t register_index;
  scalar_data_t scalar_data;
  logic [GLOBAL_ADDR_WIDTH-1:0] memory_addr;
  logic [SHARED_DATA_WIDTH-1:0] memory_data;
  scheduler_policy_e scheduler_policy;
  instruction_t instruction;
  logic signed [TENSOR_M-1:0][TENSOR_N-1:0]
      [TENSOR_ACC_WIDTH-1:0] tensor_data;
  perf_counters_t counters;

  `uvm_object_utils(warpforge_observation)

  function new(string name = "warpforge_observation");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf(
      "kind=%s warp=%0d opcode=%s reg=%0d scalar=%0d",
      kind.name(),
      warp_id,
      instruction.opcode.name(),
      register_index,
      scalar_data
    );
  endfunction
endclass
