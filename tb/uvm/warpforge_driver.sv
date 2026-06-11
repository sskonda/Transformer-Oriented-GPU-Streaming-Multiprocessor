class warpforge_driver extends uvm_driver #(warpforge_seq_item);
  `uvm_component_utils(warpforge_driver)

  virtual warpforge_if vif;
  logic [SHARED_DATA_WIDTH-1:0] memory
      [longint unsigned];
  int unsigned memory_latency_cycles = 1;

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
      `uvm_fatal("NO_VIF", "warpforge_driver requires warpforge_if")
    end
  endfunction

  task drive_idle();
    vif.driver_cb.clear <= 1'b0;
    vif.driver_cb.start <= 1'b0;
    vif.driver_cb.scheduler_policy <= SCHED_ROUND_ROBIN;
    vif.driver_cb.load_valid <= 1'b0;
    vif.driver_cb.load_warp_id <= '0;
    vif.driver_cb.load_addr <= '0;
    vif.driver_cb.load_instruction <= '0;
    vif.driver_cb.reg_load_valid <= 1'b0;
    vif.driver_cb.reg_load_warp_id <= '0;
    vif.driver_cb.reg_load_reg_idx <= '0;
    vif.driver_cb.reg_load_data <= '0;
    vif.driver_cb.global_req_ready <= 1'b1;
    vif.driver_cb.global_rsp_valid <= 1'b0;
    vif.driver_cb.global_rsp_data <= '0;
  endtask

  task apply_reset();
    vif.driver_cb.rst <= 1'b1;
    repeat (3) @(vif.driver_cb);
    vif.driver_cb.rst <= 1'b0;
    @(vif.driver_cb);
  endtask

  task drive_instruction_load(warpforge_seq_item item);
    vif.driver_cb.load_valid <= 1'b1;
    vif.driver_cb.load_warp_id <= item.warp_id;
    vif.driver_cb.load_addr <= item.instruction_addr;
    vif.driver_cb.load_instruction <= item.instruction;
    do begin
      @(vif.driver_cb);
    end while (!vif.driver_cb.load_ready);
    vif.driver_cb.load_valid <= 1'b0;
  endtask

  task drive_register_load(warpforge_seq_item item);
    vif.driver_cb.reg_load_valid <= 1'b1;
    vif.driver_cb.reg_load_warp_id <= item.warp_id;
    vif.driver_cb.reg_load_reg_idx <= item.register_index;
    vif.driver_cb.reg_load_data <= item.register_data;
    do begin
      @(vif.driver_cb);
    end while (!vif.driver_cb.reg_load_ready);
    vif.driver_cb.reg_load_valid <= 1'b0;
  endtask

  task drive_start(warpforge_seq_item item);
    vif.driver_cb.scheduler_policy <= item.scheduler_policy;
    vif.driver_cb.start <= 1'b1;
    @(vif.driver_cb);
    vif.driver_cb.start <= 1'b0;
  endtask

  task drive_clear();
    vif.driver_cb.clear <= 1'b1;
    @(vif.driver_cb);
    vif.driver_cb.clear <= 1'b0;
  endtask

  task drive_items();
    forever begin
      seq_item_port.get_next_item(req);
      unique case (req.command)
        CMD_LOAD_INSTRUCTION: drive_instruction_load(req);
        CMD_LOAD_REGISTER: drive_register_load(req);
        CMD_LOAD_MEMORY:
            memory[longint'(req.memory_addr)] = req.memory_data;
        CMD_START: drive_start(req);
        CMD_CLEAR: drive_clear();
        default: `uvm_error("BAD_COMMAND", req.convert2string())
      endcase
      seq_item_port.item_done();
    end
  endtask

  task service_memory();
    logic request_pending;
    logic response_active;
    logic [GLOBAL_ADDR_WIDTH-1:0] request_addr;
    int unsigned delay_remaining;

    request_pending = 1'b0;
    response_active = 1'b0;
    delay_remaining = '0;

    forever begin
      @(vif.driver_cb);

      if (response_active && vif.driver_cb.global_rsp_ready) begin
        vif.driver_cb.global_rsp_valid <= 1'b0;
        response_active = 1'b0;
      end

      if (vif.driver_cb.global_req_valid && !request_pending) begin
        request_addr = vif.driver_cb.global_req_addr;
        request_pending = 1'b1;
        delay_remaining = memory_latency_cycles;
      end

      if (request_pending && !response_active) begin
        if (delay_remaining != 0) begin
          delay_remaining--;
        end else begin
          if (!memory.exists(longint'(request_addr))) begin
            `uvm_error(
              "MEMORY_MISS",
              $sformatf("No data loaded at word address %0d", request_addr)
            )
            vif.driver_cb.global_rsp_data <= '0;
          end else begin
            vif.driver_cb.global_rsp_data <=
                memory[longint'(request_addr)];
          end
          vif.driver_cb.global_rsp_valid <= 1'b1;
          request_pending = 1'b0;
          response_active = 1'b1;
        end
      end
    end
  endtask

  task run_phase(uvm_phase phase);
    drive_idle();
    apply_reset();
    fork
      drive_items();
      service_memory();
    join
  endtask
endclass
