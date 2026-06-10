module shared_memory #(
  parameter int unsigned NUM_PORTS = 2,
  parameter int unsigned NUM_BANKS = warpforge_pkg::SHARED_NUM_BANKS,
  parameter int unsigned ADDR_WIDTH = warpforge_pkg::SHARED_ADDR_WIDTH,
  parameter int unsigned DATA_WIDTH = warpforge_pkg::SHARED_DATA_WIDTH,
  parameter int unsigned COUNTER_WIDTH = 32
) (
  input  logic clk,
  input  logic rst,
  input  logic clear,
  input  logic [NUM_PORTS-1:0] req_valid,
  output logic [NUM_PORTS-1:0] req_ready,
  input  logic [NUM_PORTS-1:0] req_write,
  input  wire logic [NUM_PORTS-1:0][ADDR_WIDTH-1:0] req_addr,
  input  wire logic [NUM_PORTS-1:0][DATA_WIDTH-1:0] req_wdata,
  output logic [NUM_PORTS-1:0] rsp_valid,
  output logic [NUM_PORTS-1:0][DATA_WIDTH-1:0] rsp_rdata,
  output logic conflict_event,
  output logic [COUNTER_WIDTH-1:0] conflict_count
);

  localparam int unsigned BANK_INDEX_WIDTH =
      (NUM_BANKS > 1) ? $clog2(NUM_BANKS) : 1;
  localparam int unsigned ROW_ADDR_WIDTH = ADDR_WIDTH - BANK_INDEX_WIDTH;
  localparam int unsigned ROWS_PER_BANK = 1 << ROW_ADDR_WIDTH;
  localparam int unsigned LOSER_COUNT_WIDTH =
      (NUM_PORTS > 1) ? $clog2(NUM_PORTS + 1) : 1;

  logic [DATA_WIDTH-1:0] mem [0:NUM_BANKS-1][0:ROWS_PER_BANK-1];
  logic [NUM_PORTS-1:0] grant;
  logic [NUM_PORTS-1:0] rsp_valid_r;
  logic [NUM_PORTS-1:0][DATA_WIDTH-1:0] rsp_rdata_r;
  logic [LOSER_COUNT_WIDTH-1:0] conflict_losers;

  function automatic logic [BANK_INDEX_WIDTH-1:0] address_bank(
    input logic [ADDR_WIDTH-1:0] address
  );
    return address[BANK_INDEX_WIDTH-1:0];
  endfunction

  function automatic logic [ROW_ADDR_WIDTH-1:0] address_row(
    input logic [ADDR_WIDTH-1:0] address
  );
    return address[ADDR_WIDTH-1:BANK_INDEX_WIDTH];
  endfunction

  always_comb begin
    req_ready = '0;
    grant = '0;
    conflict_losers = '0;

    for (int unsigned bank = 0; bank < NUM_BANKS; bank++) begin
      logic bank_granted;
      bank_granted = 1'b0;

      for (int unsigned port = 0; port < NUM_PORTS; port++) begin
        if (req_valid[port] && address_bank(req_addr[port]) == bank) begin
          if (!bank_granted) begin
            req_ready[port] = 1'b1;
            grant[port] = 1'b1;
            bank_granted = 1'b1;
          end else begin
            conflict_losers = conflict_losers + 1'b1;
          end
        end
      end
    end
  end

  assign conflict_event = conflict_losers != '0;
  assign rsp_valid = rsp_valid_r;
  assign rsp_rdata = rsp_rdata_r;

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      rsp_valid_r <= '0;
      conflict_count <= '0;
    end else begin
      rsp_valid_r <= '0;

      for (int unsigned port = 0; port < NUM_PORTS; port++) begin
        if (grant[port]) begin
          if (req_write[port]) begin
            mem[address_bank(req_addr[port])][address_row(req_addr[port])]
                <= req_wdata[port];
          end else begin
            rsp_valid_r[port] <= 1'b1;
            rsp_rdata_r[port]
                <= mem[address_bank(req_addr[port])][address_row(req_addr[port])];
          end
        end
      end

      if (conflict_event) begin
        conflict_count <= conflict_count + conflict_losers;
      end
    end
  end

  initial begin
    if (NUM_PORTS == 0 || NUM_BANKS == 0) begin
      $fatal(1, "shared_memory port and bank counts must be greater than zero");
    end
    if ((NUM_BANKS & (NUM_BANKS - 1)) != 0) begin
      $fatal(1, "shared_memory NUM_BANKS must be a power of two");
    end
    if (ADDR_WIDTH <= BANK_INDEX_WIDTH || DATA_WIDTH == 0) begin
      $fatal(1, "shared_memory address or data width is invalid");
    end
  end

`ifndef SYNTHESIS
  shared_memory_sva #(
    .NUM_PORTS(NUM_PORTS),
    .ADDR_WIDTH(ADDR_WIDTH),
    .COUNTER_WIDTH(COUNTER_WIDTH)
  ) assertions (
    .clk,
    .rst,
    .clear,
    .req_valid,
    .req_ready,
    .req_addr,
    .rsp_valid,
    .conflict_event,
    .conflict_count
  );
`endif

endmodule
