class warpforge_env extends uvm_env;
  `uvm_component_utils(warpforge_env)

  warpforge_agent agent;
  warpforge_ref_model reference_model;
  warpforge_scoreboard scoreboard;
  warpforge_coverage coverage;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = warpforge_agent::type_id::create("agent", this);
    reference_model =
        warpforge_ref_model::type_id::create("reference_model", this);
    scoreboard = warpforge_scoreboard::type_id::create("scoreboard", this);
    coverage = warpforge_coverage::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.monitor.observation_ap.connect(
      reference_model.observation_export
    );
    agent.monitor.observation_ap.connect(scoreboard.actual_export);
    agent.monitor.observation_ap.connect(coverage.analysis_export);
    reference_model.expected_ap.connect(scoreboard.expected_export);
  endfunction
endclass
