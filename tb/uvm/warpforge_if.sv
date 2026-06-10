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

  logic global_rsp_valid;
  logic global_rsp_ready;
  logic [SHARED_DATA_WIDTH-1:0] global_rsp_data;

  logic busy;
  logic done;
  logic issue_valid;
  warp_id_t issue_warp_id;
  instruction_t issue_instruction;
  logic [NUM_WARPS-1:0] warp_done;
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
    output global_rsp_valid;
    output global_rsp_data;
    input load_ready;
    input global_rsp_ready;
    input busy;
    input done;
    input issue_valid;
    input issue_warp_id;
    input issue_instruction;
    input warp_done;
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
    input global_rsp_valid;
    input global_rsp_ready;
    input global_rsp_data;
    input busy;
    input done;
    input issue_valid;
    input issue_warp_id;
    input issue_instruction;
    input warp_done;
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
    input global_rsp_valid,
    input global_rsp_data,
    output load_ready,
    output global_rsp_ready,
    output busy,
    output done,
    output issue_valid,
    output issue_warp_id,
    output issue_instruction,
    output warp_done,
    output counters
  );

  modport DRIVER (clocking driver_cb);
  modport MONITOR (clocking monitor_cb);

endinterface
