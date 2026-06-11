class warpforge_coverage extends uvm_subscriber #(warpforge_observation);
  `uvm_component_utils(warpforge_coverage)

  warpforge_observation_e sampled_kind;
  opcode_e sampled_opcode;
  scheduler_policy_e sampled_policy;
  warp_id_t sampled_warp;
  logic sampled_negative;
  logic sampled_zero;

`ifndef WARPFORGE_DISABLE_COVERAGE
  covergroup architecture_cg;
    option.per_instance = 1;
    kind_cp: coverpoint sampled_kind;
    opcode_cp: coverpoint sampled_opcode;
    policy_cp: coverpoint sampled_policy;
    warp_cp: coverpoint sampled_warp;
    negative_cp: coverpoint sampled_negative;
    zero_cp: coverpoint sampled_zero;
    policy_opcode_cross: cross policy_cp, opcode_cp;
  endgroup
`endif

  function new(string name, uvm_component parent);
    super.new(name, parent);
`ifndef WARPFORGE_DISABLE_COVERAGE
    architecture_cg = new();
`endif
  endfunction

  function void write(warpforge_observation t);
    sampled_kind = t.kind;
    sampled_opcode = t.instruction.opcode;
    sampled_policy = t.scheduler_policy;
    sampled_warp = t.warp_id;
    sampled_negative = 1'b0;
    sampled_zero = 1'b0;

    if (t.kind == OBS_SCALAR_RESULT) begin
      sampled_negative = t.scalar_data < 0;
      sampled_zero = t.scalar_data == 0;
    end
    if (t.kind == OBS_TENSOR_RESULT) begin
      sampled_negative = t.tensor_data[0][0] < 0;
      sampled_zero = t.tensor_data == '0;
    end
`ifndef WARPFORGE_DISABLE_COVERAGE
    architecture_cg.sample();
`endif
  endfunction
endclass
