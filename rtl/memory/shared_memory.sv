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
  localparam int unsigned PORT_INDEX_WIDTH =
      (NUM_PORTS > 1) ? $clog2(NUM_PORTS) : 1;
  localparam int unsigned LOSER_COUNT_WIDTH =
      (NUM_PORTS > 1) ? $clog2(NUM_PORTS + 1) : 1;

  logic [NUM_BANKS-1:0] bank_valid;
  logic [NUM_BANKS-1:0] bank_write;
  logic [NUM_BANKS-1:0][ROW_ADDR_WIDTH-1:0] bank_row;
  logic [NUM_BANKS-1:0][DATA_WIDTH-1:0] bank_wdata;
  logic [NUM_BANKS-1:0][PORT_INDEX_WIDTH-1:0] bank_port;
  logic [NUM_BANKS-1:0] bank_rd_valid;
  logic [NUM_BANKS-1:0][DATA_WIDTH-1:0] bank_rd_data;
  logic [NUM_BANKS-1:0][PORT_INDEX_WIDTH-1:0] bank_rsp_port_r;
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

  function automatic logic [COUNTER_WIDTH-1:0] saturating_add(
    input logic [COUNTER_WIDTH-1:0] value,
    input logic [LOSER_COUNT_WIDTH-1:0] increment
  );
    logic [COUNTER_WIDTH:0] sum;

    sum = {1'b0, value} +
        {{(COUNTER_WIDTH + 1 - LOSER_COUNT_WIDTH){1'b0}}, increment};
    return sum[COUNTER_WIDTH]
        ? {COUNTER_WIDTH{1'b1}}
        : sum[COUNTER_WIDTH-1:0];
  endfunction

  always_comb begin
    req_ready = '0;
    bank_valid = '0;
    bank_write = '0;
    bank_row = '0;
    bank_wdata = '0;
    bank_port = '0;
    conflict_losers = '0;

    for (int unsigned bank = 0; bank < NUM_BANKS; bank++) begin
      for (int unsigned port = 0; port < NUM_PORTS; port++) begin
        if (
          req_valid[port] &&
          address_bank(req_addr[port]) == BANK_INDEX_WIDTH'(bank)
        ) begin
          if (!bank_valid[bank]) begin
            req_ready[port] = 1'b1;
            bank_valid[bank] = 1'b1;
            bank_write[bank] = req_write[port];
            bank_row[bank] = address_row(req_addr[port]);
            bank_wdata[bank] = req_wdata[port];
            bank_port[bank] = port[PORT_INDEX_WIDTH-1:0];
          end else begin
            conflict_losers = conflict_losers + 1'b1;
          end
        end
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst || clear) begin
      bank_rsp_port_r <= '0;
      conflict_count <= '0;
    end else begin
      for (int unsigned bank = 0; bank < NUM_BANKS; bank++) begin
        if (bank_valid[bank] && !bank_write[bank]) begin
          bank_rsp_port_r[bank] <= bank_port[bank];
        end
      end

      if (conflict_event) begin
        conflict_count <=
            saturating_add(conflict_count, conflict_losers);
      end
    end
  end

  always_comb begin
    rsp_valid = '0;
    rsp_rdata = '0;

    for (int unsigned bank = 0; bank < NUM_BANKS; bank++) begin
      if (bank_rd_valid[bank]) begin
        rsp_valid[bank_rsp_port_r[bank]] = 1'b1;
        rsp_rdata[bank_rsp_port_r[bank]] = bank_rd_data[bank];
      end
    end
  end

  assign conflict_event = conflict_losers != '0;

  generate
    for (genvar bank = 0; bank < NUM_BANKS; bank++) begin : g_bank
      ram_sdp #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ROW_ADDR_WIDTH)
      ) storage (
        .clk,
        .rst(rst || clear),
        .rd_en(bank_valid[bank] && !bank_write[bank]),
        .rd_addr(bank_row[bank]),
        .rd_valid(bank_rd_valid[bank]),
        .rd_data(bank_rd_data[bank]),
        .wr_en(bank_valid[bank] && bank_write[bank]),
        .wr_addr(bank_row[bank]),
        .wr_data(bank_wdata[bank])
      );
    end
  endgenerate

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
    .req_write,
    .req_addr,
    .rsp_valid,
    .conflict_event,
    .conflict_count
  );
`endif

endmodule
