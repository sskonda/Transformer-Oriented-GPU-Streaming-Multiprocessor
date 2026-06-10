module shared_memory_sva #(
  parameter int unsigned NUM_PORTS = 2,
  parameter int unsigned ADDR_WIDTH = warpforge_pkg::SHARED_ADDR_WIDTH,
  parameter int unsigned COUNTER_WIDTH = 32
) (
  input logic clk,
  input logic rst,
  input logic clear,
  input logic [NUM_PORTS-1:0] req_valid,
  input logic [NUM_PORTS-1:0] req_ready,
  input wire logic [NUM_PORTS-1:0][ADDR_WIDTH-1:0] req_addr,
  input logic [NUM_PORTS-1:0] rsp_valid,
  input logic conflict_event,
  input logic [COUNTER_WIDTH-1:0] conflict_count
);

  assert property (@(posedge clk) disable iff (rst || clear)
    (req_ready & ~req_valid) == '0);

  assert property (@(posedge clk) disable iff (rst || clear)
    conflict_event == |(req_valid & ~req_ready));

  assert property (@(posedge clk) disable iff (rst || clear)
    !$isunknown({req_ready, rsp_valid, conflict_event}));

  assert property (@(posedge clk) disable iff (rst || clear)
    conflict_count >= $past(conflict_count));

  generate
    for (genvar port = 0; port < NUM_PORTS; port++) begin : g_address_known
      assert property (@(posedge clk) disable iff (rst || clear)
        req_valid[port] |-> !$isunknown(req_addr[port]));
    end
  endgenerate

endmodule
