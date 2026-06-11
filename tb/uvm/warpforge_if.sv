interface warpforge_if (
  input logic clk
);
  import warpforge_pkg::*;

  logic rst;
  logic clear;
  logic start;
  scheduler_policy_e scheduler_policy;

  logic load_valid;
  logic load_ready;
  warp_id_t load_warp_id;
  instr_addr_t load_addr;
  instruction_t load_instruction;

  logic reg_load_valid;
  logic reg_load_ready;
  warp_id_t reg_load_warp_id;
  reg_idx_t reg_load_reg_idx;
  scalar_data_t reg_load_data;

  logic global_req_valid;
  logic global_req_ready;
  logic [GLOBAL_ADDR_WIDTH-1:0] global_req_addr;
  logic global_rsp_valid;
  logic global_rsp_ready;
  logic [SHARED_DATA_WIDTH-1:0] global_rsp_data;

  logic busy;
  logic done;
  logic issue_valid;
  warp_id_t issue_warp_id;
  instruction_t issue_instruction;
  logic [NUM_WARPS-1:0] warp_done;
  logic [NUM_WARPS-1:0] warp_error;
  logic scalar_result_valid;
  warp_id_t scalar_result_warp_id;
  reg_idx_t scalar_result_dst;
  scalar_data_t scalar_result_data;
  logic tensor_result_valid;
  warp_id_t tensor_result_warp_id;
  reg_idx_t tensor_result_dst;
  logic signed [TENSOR_M-1:0][TENSOR_N-1:0]
      [TENSOR_ACC_WIDTH-1:0] tensor_result;
  logic [NUM_WARPS-1:0][NUM_TILES-1:0] tile_valid;
  perf_counters_t counters;

  clocking driver_cb @(posedge clk);
    default input #1step output #0;
    output rst;
    output clear;
    output start;
    output scheduler_policy;
    output load_valid;
    output load_warp_id;
    output load_addr;
    output load_instruction;
    output reg_load_valid;
    output reg_load_warp_id;
    output reg_load_reg_idx;
    output reg_load_data;
    output global_req_ready;
    output global_rsp_valid;
    output global_rsp_data;
    input load_ready;
    input reg_load_ready;
    input global_req_valid;
    input global_req_addr;
    input global_rsp_ready;
    input busy;
    input done;
    input issue_valid;
    input issue_warp_id;
    input issue_instruction;
    input warp_done;
    input warp_error;
    input scalar_result_valid;
    input scalar_result_warp_id;
    input scalar_result_dst;
    input scalar_result_data;
    input tensor_result_valid;
    input tensor_result_warp_id;
    input tensor_result_dst;
    input tensor_result;
    input tile_valid;
    input counters;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1step;
    input rst;
    input clear;
    input start;
    input scheduler_policy;
    input load_valid;
    input load_ready;
    input load_warp_id;
    input load_addr;
    input load_instruction;
    input reg_load_valid;
    input reg_load_ready;
    input reg_load_warp_id;
    input reg_load_reg_idx;
    input reg_load_data;
    input global_req_valid;
    input global_req_ready;
    input global_req_addr;
    input global_rsp_valid;
    input global_rsp_ready;
    input global_rsp_data;
    input busy;
    input done;
    input issue_valid;
    input issue_warp_id;
    input issue_instruction;
    input warp_done;
    input warp_error;
    input scalar_result_valid;
    input scalar_result_warp_id;
    input scalar_result_dst;
    input scalar_result_data;
    input tensor_result_valid;
    input tensor_result_warp_id;
    input tensor_result_dst;
    input tensor_result;
    input tile_valid;
    input counters;
  endclocking

  modport DUT (
    input clk,
    input rst,
    input clear,
    input start,
    input scheduler_policy,
    input load_valid,
    input load_warp_id,
    input load_addr,
    input load_instruction,
    input reg_load_valid,
    input reg_load_warp_id,
    input reg_load_reg_idx,
    input reg_load_data,
    input global_req_ready,
    input global_rsp_valid,
    input global_rsp_data,
    output load_ready,
    output reg_load_ready,
    output global_req_valid,
    output global_req_addr,
    output global_rsp_ready,
    output busy,
    output done,
    output issue_valid,
    output issue_warp_id,
    output issue_instruction,
    output warp_done,
    output warp_error,
    output scalar_result_valid,
    output scalar_result_warp_id,
    output scalar_result_dst,
    output scalar_result_data,
    output tensor_result_valid,
    output tensor_result_warp_id,
    output tensor_result_dst,
    output tensor_result,
    output tile_valid,
    output counters
  );

  modport DRIVER (clocking driver_cb);
  modport MONITOR (clocking monitor_cb);

endinterface
