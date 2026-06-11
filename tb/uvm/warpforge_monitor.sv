class warpforge_monitor extends uvm_monitor;
  `uvm_component_utils(warpforge_monitor)

  virtual warpforge_if vif;
  uvm_analysis_port #(warpforge_observation) observation_ap;
  logic [NUM_WARPS-1:0] previous_warp_done;
  logic [NUM_WARPS-1:0] previous_warp_error;
  logic previous_rst;
  logic previous_clear;
  logic previous_done;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    observation_ap = new("observation_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual warpforge_if)::get(
      this,
      "",
      "vif",
      vif
    )) begin
      `uvm_fatal("NO_VIF", "warpforge_monitor requires warpforge_if")
    end
  endfunction

  function warpforge_observation create_observation(
    warpforge_observation_e kind,
    string name
  );
    warpforge_observation observation;
    observation = warpforge_observation::type_id::create(name);
    observation.kind = kind;
    observation.scheduler_policy = vif.monitor_cb.scheduler_policy;
    return observation;
  endfunction

  task run_phase(uvm_phase phase);
    warpforge_observation observation;

    previous_warp_done = '0;
    previous_warp_error = '0;
    previous_rst = 1'b0;
    previous_clear = 1'b0;
    previous_done = 1'b0;

    forever begin
      @(vif.monitor_cb);

      if (vif.monitor_cb.rst && !previous_rst) begin
        observation = create_observation(OBS_RESET, "reset_observation");
        observation_ap.write(observation);
      end
      if (vif.monitor_cb.clear && !previous_clear) begin
        observation = create_observation(OBS_CLEAR, "clear_observation");
        observation_ap.write(observation);
      end
      if (vif.monitor_cb.load_valid && vif.monitor_cb.load_ready) begin
        observation = create_observation(
          OBS_INSTRUCTION_LOAD,
          "instruction_load_observation"
        );
        observation.warp_id = vif.monitor_cb.load_warp_id;
        observation.instruction_addr = vif.monitor_cb.load_addr;
        observation.instruction = vif.monitor_cb.load_instruction;
        observation_ap.write(observation);
      end
      if (vif.monitor_cb.reg_load_valid && vif.monitor_cb.reg_load_ready) begin
        observation = create_observation(
          OBS_REGISTER_LOAD,
          "register_load_observation"
        );
        observation.warp_id = vif.monitor_cb.reg_load_warp_id;
        observation.register_index = vif.monitor_cb.reg_load_reg_idx;
        observation.scalar_data = vif.monitor_cb.reg_load_data;
        observation_ap.write(observation);
      end
      if (
        vif.monitor_cb.global_req_valid &&
        vif.monitor_cb.global_req_ready
      ) begin
        observation = create_observation(
          OBS_GLOBAL_REQUEST,
          "global_request_observation"
        );
        observation.memory_addr = vif.monitor_cb.global_req_addr;
        observation_ap.write(observation);
      end
      if (
        vif.monitor_cb.global_rsp_valid &&
        vif.monitor_cb.global_rsp_ready
      ) begin
        observation = create_observation(
          OBS_GLOBAL_RESPONSE,
          "global_response_observation"
        );
        observation.memory_data = vif.monitor_cb.global_rsp_data;
        observation_ap.write(observation);
      end
      if (vif.monitor_cb.issue_valid) begin
        observation = create_observation(OBS_ISSUE, "issue_observation");
        observation.warp_id = vif.monitor_cb.issue_warp_id;
        observation.instruction = vif.monitor_cb.issue_instruction;
        observation_ap.write(observation);
      end
      if (vif.monitor_cb.scalar_result_valid) begin
        observation = create_observation(
          OBS_SCALAR_RESULT,
          "scalar_result_observation"
        );
        observation.warp_id = vif.monitor_cb.scalar_result_warp_id;
        observation.register_index = vif.monitor_cb.scalar_result_dst;
        observation.scalar_data = vif.monitor_cb.scalar_result_data;
        observation_ap.write(observation);
      end
      if (vif.monitor_cb.tensor_result_valid) begin
        observation = create_observation(
          OBS_TENSOR_RESULT,
          "tensor_result_observation"
        );
        observation.warp_id = vif.monitor_cb.tensor_result_warp_id;
        observation.register_index = vif.monitor_cb.tensor_result_dst;
        observation.tensor_data = vif.monitor_cb.tensor_result;
        observation_ap.write(observation);
      end

      for (int unsigned warp = 0; warp < NUM_WARPS; warp++) begin
        if (
          vif.monitor_cb.warp_done[warp] &&
          !previous_warp_done[warp]
        ) begin
          observation = create_observation(
            OBS_WARP_DONE,
            "warp_done_observation"
          );
          observation.warp_id = warp_id_t'(warp);
          observation_ap.write(observation);
        end
        if (
          vif.monitor_cb.warp_error[warp] &&
          !previous_warp_error[warp]
        ) begin
          observation = create_observation(
            OBS_WARP_ERROR,
            "warp_error_observation"
          );
          observation.warp_id = warp_id_t'(warp);
          observation_ap.write(observation);
        end
      end

      if (vif.monitor_cb.done && !previous_done) begin
        observation = create_observation(OBS_DONE, "done_observation");
        observation.counters = vif.monitor_cb.counters;
        observation_ap.write(observation);
      end

      previous_warp_done = vif.monitor_cb.warp_done;
      previous_warp_error = vif.monitor_cb.warp_error;
      previous_rst = vif.monitor_cb.rst;
      previous_clear = vif.monitor_cb.clear;
      previous_done = vif.monitor_cb.done;
    end
  endtask
endclass
