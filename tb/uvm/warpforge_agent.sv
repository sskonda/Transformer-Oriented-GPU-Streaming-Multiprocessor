class warpforge_agent extends uvm_agent;
  `uvm_component_utils(warpforge_agent)

  uvm_sequencer #(warpforge_seq_item) sequencer;
  warpforge_driver driver;
  warpforge_monitor monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = warpforge_monitor::type_id::create("monitor", this);
    if (get_is_active() == UVM_ACTIVE) begin
      sequencer = uvm_sequencer#(warpforge_seq_item)::type_id::create(
        "sequencer",
        this
      );
      driver = warpforge_driver::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction
endclass
