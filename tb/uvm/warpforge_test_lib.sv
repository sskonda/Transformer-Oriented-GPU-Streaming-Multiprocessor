class warpforge_base_test extends uvm_test;
  `uvm_component_utils(warpforge_base_test)

  localparam int unsigned TEST_TIMEOUT_CYCLES = 1500;

  warpforge_env env;
  virtual warpforge_if vif;
  string performance_workload;

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

  function void report_phase(uvm_phase phase);
    uvm_report_server report_server;
    int error_count;
    int fatal_count;

    super.report_phase(phase);
    report_server = uvm_report_server::get_server();
    error_count = report_server.get_severity_count(UVM_ERROR);
    fatal_count = report_server.get_severity_count(UVM_FATAL);
    if ((error_count != 0) || (fatal_count != 0)) begin
      $fatal(
        1,
        "WarpForge UVM test failed with %0d errors and %0d fatals",
        error_count,
        fatal_count
      );
    end
  endfunction

  task execute_sequence(
    uvm_sequence #(warpforge_seq_item) test_sequence,
    output logic completed
  );
    int unsigned seed;
    string workload_name;

    test_sequence.start(env.agent.sequencer);
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
      `uvm_error("TIMEOUT", "WarpForge test program did not complete")
    end else begin
      seed = 1;
      void'($value$plusargs("SEED=%d", seed));
      workload_name = performance_workload;
      if (workload_name.len() == 0) begin
        workload_name = get_type_name();
      end
      `uvm_info(
        "PERF",
        $sformatf(
          {
            "WARPFORGE_PERF workload=uvm_%s policy=%s seed=%0d ",
            "cycles=%0d issued=%0d scalar=%0d tensor=%0d prefetch=%0d ",
            "scheduler_stall=%0d scoreboard_stall=%0d tile_wait=%0d ",
            "tensor_wait=%0d prefetch_stall=%0d tensor_busy=%0d ",
            "tensor_accepted=%0d tensor_completed=%0d bank_conflicts=%0d ",
            "prefetch_requests=%0d prefetch_stalls=%0d ",
            "completed_warps=%0d illegal=%0d"
          },
          workload_name,
          vif.monitor_cb.scheduler_policy.name(),
          seed,
          vif.monitor_cb.counters.total_cycles,
          vif.monitor_cb.counters.issued_instructions,
          vif.monitor_cb.counters.scalar_instructions,
          vif.monitor_cb.counters.tensor_instructions,
          vif.monitor_cb.counters.prefetch_instructions,
          vif.monitor_cb.counters.scheduler_stall_cycles,
          vif.monitor_cb.counters.scoreboard_stall_cycles,
          vif.monitor_cb.counters.tile_wait_cycles,
          vif.monitor_cb.counters.tensor_wait_cycles,
          vif.monitor_cb.counters.prefetch_stall_cycles,
          vif.monitor_cb.counters.tensor_busy_cycles,
          vif.monitor_cb.counters.tensor_accepted,
          vif.monitor_cb.counters.tensor_completed,
          vif.monitor_cb.counters.bank_conflicts,
          vif.monitor_cb.counters.prefetch_requests,
          vif.monitor_cb.counters.prefetch_stalls,
          vif.monitor_cb.counters.completed_warps,
          vif.monitor_cb.counters.illegal_instructions
        ),
        UVM_NONE
      )
    end
    repeat (2) @(vif.monitor_cb);
  endtask
endclass

class warpforge_policy_test extends warpforge_base_test;
  `uvm_component_utils(warpforge_policy_test)

  scheduler_policy_e policy = SCHED_ROUND_ROBIN;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    performance_workload = "scheduler_smoke";
  endfunction

  task run_phase(uvm_phase phase);
    warpforge_smoke_sequence test_sequence;
    logic completed;
    phase.raise_objection(this);
    test_sequence =
        warpforge_smoke_sequence::type_id::create("test_sequence");
    test_sequence.policy = policy;
    execute_sequence(test_sequence, completed);
    phase.drop_objection(this);
  endtask
endclass

class sanity_smoke_test extends warpforge_policy_test;
  `uvm_component_utils(sanity_smoke_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    policy = SCHED_ROUND_ROBIN;
  endfunction
endclass

class scheduler_round_robin_test extends warpforge_policy_test;
  `uvm_component_utils(scheduler_round_robin_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    policy = SCHED_ROUND_ROBIN;
  endfunction
endclass

class scheduler_greedy_test extends warpforge_policy_test;
  `uvm_component_utils(scheduler_greedy_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    policy = SCHED_GREEDY;
  endfunction
endclass

class scheduler_memory_aware_test extends warpforge_policy_test;
  `uvm_component_utils(scheduler_memory_aware_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    policy = SCHED_MEMORY_AWARE;
  endfunction
endclass

class top_multi_warp_contention_test extends warpforge_policy_test;
  `uvm_component_utils(top_multi_warp_contention_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    policy = SCHED_ROUND_ROBIN;
  endfunction
endclass

class top_single_warp_gemm_test extends warpforge_base_test;
  `uvm_component_utils(top_single_warp_gemm_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    warpforge_single_gemm_sequence test_sequence;
    logic completed;
    phase.raise_objection(this);
    test_sequence =
        warpforge_single_gemm_sequence::type_id::create("test_sequence");
    execute_sequence(test_sequence, completed);
    phase.drop_objection(this);
  endtask
endclass

class barrier_synchronization_test extends warpforge_base_test;
  `uvm_component_utils(barrier_synchronization_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    warpforge_barrier_sequence test_sequence;
    logic completed;
    phase.raise_objection(this);
    test_sequence =
        warpforge_barrier_sequence::type_id::create("test_sequence");
    execute_sequence(test_sequence, completed);
    phase.drop_objection(this);
  endtask
endclass

class illegal_instruction_test extends warpforge_base_test;
  `uvm_component_utils(illegal_instruction_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    warpforge_illegal_sequence test_sequence;
    logic completed;
    phase.raise_objection(this);
    test_sequence =
        warpforge_illegal_sequence::type_id::create("test_sequence");
    execute_sequence(test_sequence, completed);
    phase.drop_objection(this);
  endtask
endclass

class reset_mid_operation_test extends warpforge_base_test;
  `uvm_component_utils(reset_mid_operation_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
    warpforge_reset_recovery_sequence test_sequence;
    logic completed;
    phase.raise_objection(this);
    test_sequence =
        warpforge_reset_recovery_sequence::type_id::create("test_sequence");
    execute_sequence(test_sequence, completed);
    phase.drop_objection(this);
  endtask
endclass

class warpforge_random_test extends warpforge_base_test;
  `uvm_component_utils(warpforge_random_test)

  int unsigned warp_count = 2;
  int unsigned instructions_per_warp = 8;
  scheduler_policy_e policy = SCHED_ROUND_ROBIN;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    warpforge_random_scalar_sequence test_sequence;
    logic completed;
    phase.raise_objection(this);
    test_sequence =
        warpforge_random_scalar_sequence::type_id::create("test_sequence");
    test_sequence.warp_count = warp_count;
    test_sequence.instructions_per_warp = instructions_per_warp;
    test_sequence.policy = policy;
    execute_sequence(test_sequence, completed);
    phase.drop_objection(this);
  endtask
endclass

class constrained_random_instruction_test extends warpforge_random_test;
  `uvm_component_utils(constrained_random_instruction_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    warp_count = 2;
    instructions_per_warp = 10;
  endfunction
endclass

class random_multi_warp_test extends warpforge_random_test;
  `uvm_component_utils(random_multi_warp_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    warp_count = NUM_WARPS;
    instructions_per_warp = 8;
    policy = SCHED_ROUND_ROBIN;
  endfunction
endclass

class long_regression_test extends warpforge_random_test;
  `uvm_component_utils(long_regression_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    warp_count = NUM_WARPS;
    instructions_per_warp = 24;
    policy = SCHED_MEMORY_AWARE;
  endfunction
endclass

class random_memory_latency_test extends warpforge_policy_test;
  `uvm_component_utils(random_memory_latency_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    uvm_config_db#(int unsigned)::set(
      this,
      "env.agent.driver",
      "memory_latency_min",
      1
    );
    uvm_config_db#(int unsigned)::set(
      this,
      "env.agent.driver",
      "memory_latency_max",
      8
    );
    super.build_phase(phase);
  endfunction
endclass

class random_backpressure_test extends random_memory_latency_test;
  `uvm_component_utils(random_backpressure_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  function void build_phase(uvm_phase phase);
    uvm_config_db#(int unsigned)::set(
      this,
      "env.agent.driver",
      "memory_stall_enable",
      1
    );
    super.build_phase(phase);
  endfunction
endclass
