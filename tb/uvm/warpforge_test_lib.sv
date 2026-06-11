class warpforge_base_test extends uvm_test;
  `uvm_component_utils(warpforge_base_test)

  localparam int unsigned TEST_TIMEOUT_CYCLES = 500;

  warpforge_env env;
  virtual warpforge_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual warpforge_if)::get(
      this,
      "",
      "vif",
      vif
    )) begin
      `uvm_fatal("NO_VIF", "warpforge_base_test requires warpforge_if")
    end
    env = warpforge_env::type_id::create("env", this);
  endfunction
endclass

class sanity_smoke_test extends warpforge_base_test;
  `uvm_component_utils(sanity_smoke_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    warpforge_smoke_sequence smoke_sequence;
    logic completed;

    phase.raise_objection(this);
    smoke_sequence =
        warpforge_smoke_sequence::type_id::create("smoke_sequence");
    smoke_sequence.start(env.agent.sequencer);

    completed = 1'b0;
    for (
      int unsigned cycle = 0;
      cycle < TEST_TIMEOUT_CYCLES;
      cycle++
    ) begin
      @(vif.monitor_cb);
      if (vif.monitor_cb.done) begin
        completed = 1'b1;
        break;
      end
    end
    if (!completed) begin
      `uvm_error("TIMEOUT", "WarpForge smoke program did not complete")
    end
    repeat (2) @(vif.monitor_cb);
    phase.drop_objection(this);
  endtask
endclass
