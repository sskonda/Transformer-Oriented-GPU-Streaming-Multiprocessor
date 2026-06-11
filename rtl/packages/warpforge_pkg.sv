package warpforge_pkg;

  parameter int unsigned NUM_WARPS = 4;
  parameter int unsigned NUM_REGS = 32;
  parameter int unsigned NUM_TILES = 4;
  parameter int unsigned NUM_LANES = 32;
  parameter int unsigned INSTR_MEM_DEPTH = 32;
  parameter int unsigned SHARED_NUM_BANKS = 4;
  parameter int unsigned SHARED_ADDR_WIDTH = 8;
  parameter int unsigned SHARED_DATA_WIDTH = 32;
  parameter int unsigned SCALAR_DATA_WIDTH = 32;
  parameter int unsigned PREFETCH_QUEUE_DEPTH = 4;
  parameter int unsigned PREFETCH_MAX_TRANSFER_WORDS = 16;
  parameter int unsigned GLOBAL_ADDR_WIDTH = 32;
  parameter int unsigned TENSOR_M = 4;
  parameter int unsigned TENSOR_N = 4;
  parameter int unsigned TENSOR_K = 4;
  parameter int unsigned TENSOR_INPUT_WIDTH = 8;
  parameter int unsigned TENSOR_ACC_WIDTH = 32;
  parameter int unsigned TENSOR_PIPELINE_LATENCY = 1 + $clog2(TENSOR_K);
  parameter int unsigned TENSOR_ELEMENTS_PER_WORD =
      SHARED_DATA_WIDTH / TENSOR_INPUT_WIDTH;
  parameter int unsigned TENSOR_TILE_ELEMENTS =
      (TENSOR_M * TENSOR_K) + (TENSOR_K * TENSOR_N);
  parameter int unsigned TENSOR_TILE_WORDS =
      (TENSOR_TILE_ELEMENTS + TENSOR_ELEMENTS_PER_WORD - 1) /
      TENSOR_ELEMENTS_PER_WORD;
  parameter int unsigned PERF_COUNTER_WIDTH = 64;

  localparam int unsigned WARP_ID_WIDTH = (NUM_WARPS > 1) ? $clog2(NUM_WARPS) : 1;
  localparam int unsigned REG_INDEX_WIDTH = (NUM_REGS > 1) ? $clog2(NUM_REGS) : 1;
  localparam int unsigned TILE_ID_WIDTH = (NUM_TILES > 1) ? $clog2(NUM_TILES) : 1;
  localparam int unsigned INSTR_ADDR_WIDTH =
      (INSTR_MEM_DEPTH > 1) ? $clog2(INSTR_MEM_DEPTH) : 1;

  typedef logic [WARP_ID_WIDTH-1:0] warp_id_t;
  typedef logic [REG_INDEX_WIDTH-1:0] reg_idx_t;
  typedef logic [TILE_ID_WIDTH-1:0] tile_id_t;
  typedef logic [NUM_LANES-1:0] lane_mask_t;
  typedef logic [INSTR_ADDR_WIDTH-1:0] instr_addr_t;
  typedef logic signed [TENSOR_INPUT_WIDTH-1:0] tensor_input_t;
  typedef logic signed [TENSOR_ACC_WIDTH-1:0] tensor_acc_t;
  typedef logic signed [SCALAR_DATA_WIDTH-1:0] scalar_data_t;

  typedef enum logic [3:0] {
    OP_NOP,
    OP_ALU_ADD,
    OP_ALU_MUL,
    OP_ALU_MAD,
    OP_TENSOR_MMA,
    OP_PREFETCH_TILE,
    OP_WAIT_TILE,
    OP_BARRIER,
    OP_END,
    OP_ILLEGAL = 4'hf
  } opcode_e;

  typedef enum logic [2:0] {
    WARP_IDLE,
    WARP_ACTIVE,
    WARP_WAIT_SCOREBOARD,
    WARP_WAIT_TILE,
    WARP_WAIT_TENSOR,
    WARP_WAIT_BARRIER,
    WARP_DONE,
    WARP_ERROR
  } warp_state_e;

  typedef enum logic [1:0] {
    SCHED_ROUND_ROBIN,
    SCHED_GREEDY,
    SCHED_MEMORY_AWARE
  } scheduler_policy_e;

  typedef enum logic [1:0] {
    TENSOR_ARCH_TREE,
    TENSOR_ARCH_PIPELINED_TREE,
    TENSOR_ARCH_SYSTOLIC
  } tensor_arch_e;

  typedef struct packed {
    opcode_e opcode;
    reg_idx_t dst;
    reg_idx_t src0;
    reg_idx_t src1;
    reg_idx_t src2;
    tile_id_t tile_id;
    logic [15:0] immediate;
  } instruction_t;

  typedef struct packed {
    logic [PERF_COUNTER_WIDTH-1:0] total_cycles;
    logic [PERF_COUNTER_WIDTH-1:0] issued_instructions;
    logic [PERF_COUNTER_WIDTH-1:0] tensor_instructions;
    logic [PERF_COUNTER_WIDTH-1:0] scalar_instructions;
    logic [PERF_COUNTER_WIDTH-1:0] prefetch_instructions;
    logic [PERF_COUNTER_WIDTH-1:0] scheduler_stall_cycles;
    logic [PERF_COUNTER_WIDTH-1:0] scoreboard_stall_cycles;
    logic [PERF_COUNTER_WIDTH-1:0] tile_wait_cycles;
    logic [PERF_COUNTER_WIDTH-1:0] tensor_wait_cycles;
    logic [PERF_COUNTER_WIDTH-1:0] prefetch_stall_cycles;
    logic [PERF_COUNTER_WIDTH-1:0] tensor_busy_cycles;
    logic [PERF_COUNTER_WIDTH-1:0] tensor_accepted;
    logic [PERF_COUNTER_WIDTH-1:0] tensor_completed;
    logic [PERF_COUNTER_WIDTH-1:0] bank_conflicts;
    logic [PERF_COUNTER_WIDTH-1:0] prefetch_requests;
    logic [PERF_COUNTER_WIDTH-1:0] prefetch_stalls;
    logic [PERF_COUNTER_WIDTH-1:0] completed_warps;
    logic [PERF_COUNTER_WIDTH-1:0] illegal_instructions;
  } perf_counters_t;

  function automatic int unsigned clog2_nonzero(input int unsigned value);
    return (value > 1) ? $clog2(value) : 1;
  endfunction

  function automatic logic opcode_is_scalar(input opcode_e opcode);
    return opcode inside {OP_ALU_ADD, OP_ALU_MUL, OP_ALU_MAD};
  endfunction

  function automatic logic opcode_writes_register(input opcode_e opcode);
    return opcode inside {OP_ALU_ADD, OP_ALU_MUL, OP_ALU_MAD, OP_TENSOR_MMA};
  endfunction

  function automatic logic opcode_uses_src0(input opcode_e opcode);
    return opcode inside {OP_ALU_ADD, OP_ALU_MUL, OP_ALU_MAD};
  endfunction

  function automatic logic opcode_uses_src1(input opcode_e opcode);
    return opcode inside {OP_ALU_ADD, OP_ALU_MUL, OP_ALU_MAD};
  endfunction

  function automatic logic opcode_uses_src2(input opcode_e opcode);
    return opcode == OP_ALU_MAD;
  endfunction

  function automatic logic opcode_is_legal(input opcode_e opcode);
    return opcode inside {
      OP_NOP,
      OP_ALU_ADD,
      OP_ALU_MUL,
      OP_ALU_MAD,
      OP_TENSOR_MMA,
      OP_PREFETCH_TILE,
      OP_WAIT_TILE,
      OP_BARRIER,
      OP_END
    };
  endfunction

endpackage
