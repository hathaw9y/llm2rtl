`timescale 1ns / 1ps
// Generic bank-indexed internal interface. A design wrapper chooses each request
// and demultiplexes tagged responses; no model-specific role is named here.
module bank_native_router #(
    parameter int                                                  BANK_NUM                          = 2,
    parameter int                                                  ROLE_WIDTH                        = 3,
    parameter int                                                  ADDR_WIDTH                        = 32,
    parameter int                                                  MAX_DATA_WIDTH                    = 128,
    parameter int                                                  MEMORY_READ_LATENCY               = 3,
    parameter int                                                  WRITE_WIDTHS       [0:BANK_NUM-1] = '{default: 128},
    parameter int                                                  READ_WIDTHS        [0:BANK_NUM-1] = '{default: 128},
    parameter longint unsigned                                     WRITE_DEPTHS       [0:BANK_NUM-1] = '{default: 64},
    parameter logic            [BANK_NUM-1:0][(1<<ROLE_WIDTH)-1:0] WR_CAPABILITIES                   = '0,
    parameter logic            [BANK_NUM-1:0][(1<<ROLE_WIDTH)-1:0] RD_CAPABILITIES                   = '0
) (
    input  logic                                      aclk,
    input  logic                                      aresetn,
    input  logic [BANK_NUM-1:0]                       bank_wr_busy,
    bank_rd_busy,
    input  logic [BANK_NUM-1:0][      ROLE_WIDTH-1:0] bank_wr_owner_port,
    bank_rd_owner_port,
    input  logic [BANK_NUM-1:0]                       wr_req_valid,
    rd_req_valid,
    input  logic [BANK_NUM-1:0][      ROLE_WIDTH-1:0] wr_req_owner,
    rd_req_owner,
    input  logic [BANK_NUM-1:0][      ADDR_WIDTH-1:0] wr_req_addr,
    rd_req_addr,
    input  logic [BANK_NUM-1:0][  MAX_DATA_WIDTH-1:0] wr_req_data,
    input  logic [BANK_NUM-1:0][MAX_DATA_WIDTH/8-1:0] wr_req_strb,
    output logic [BANK_NUM-1:0]                       wr_req_ready,
    rd_req_ready,
    output logic [BANK_NUM-1:0]                       rd_rsp_valid,
    output logic [BANK_NUM-1:0][      ROLE_WIDTH-1:0] rd_rsp_owner,
    output logic [BANK_NUM-1:0][  MAX_DATA_WIDTH-1:0] rd_rsp_data,
    output logic [BANK_NUM-1:0]                       bank_ena,
    bank_enb,
    output logic [BANK_NUM-1:0][MAX_DATA_WIDTH/8-1:0] bank_wea,
    output logic [BANK_NUM-1:0][      ADDR_WIDTH-1:0] bank_addra,
    bank_addrb,
    output logic [BANK_NUM-1:0][  MAX_DATA_WIDTH-1:0] bank_dina,
    input  logic [BANK_NUM-1:0][  MAX_DATA_WIDTH-1:0] bank_doutb,
    output logic                                      router_error,
    output logic [         2:0]                       router_error_code
);
  logic [BANK_NUM-1:0] rd_accept_w;
  logic [BANK_NUM-1:0] response_valid_r[0:MEMORY_READ_LATENCY];
  logic [BANK_NUM-1:0][ROLE_WIDTH-1:0] response_owner_r[0:MEMORY_READ_LATENCY];
  logic bad_request_w;
  logic [2:0] bad_code_w;
  // Generate gives constant-width part selects for heterogeneous banks.
  for (genvar b = 0; b < BANK_NUM; b++) begin : g_bank
    localparam int SAFE_READ_WIDTH = READ_WIDTHS[b] > 0 ? READ_WIDTHS[b] : 1;
    localparam longint unsigned READ_DEPTH = (WRITE_DEPTHS[b] * 64'(WRITE_WIDTHS[b])) / 64'(SAFE_READ_WIDTH);
    localparam logic CONFIG_LEGAL = BANK_NUM > 0 && ROLE_WIDTH > 0 &&
        ADDR_WIDTH > 0 && ADDR_WIDTH <= 32 && MAX_DATA_WIDTH > 0 &&
        MAX_DATA_WIDTH % 8 == 0 && MEMORY_READ_LATENCY >= 1 &&
        WRITE_WIDTHS[b] > 0 && READ_WIDTHS[b] > 0 &&
        WRITE_WIDTHS[b] <= MAX_DATA_WIDTH && READ_WIDTHS[b] <= MAX_DATA_WIDTH &&
        WRITE_WIDTHS[b] % 8 == 0 && READ_WIDTHS[b] % 8 == 0 &&
        WRITE_DEPTHS[b] > 0 && WRITE_DEPTHS[b] <= (64'd1 << ADDR_WIDTH) &&
        READ_DEPTH > 0 && READ_DEPTH <= (64'd1 << ADDR_WIDTH) &&
        (WRITE_DEPTHS[b]*64'(WRITE_WIDTHS[b])) % 64'(SAFE_READ_WIDTH) == 0 &&
        ((WRITE_WIDTHS[b] % SAFE_READ_WIDTH == 0) ||
         (READ_WIDTHS[b] % (WRITE_WIDTHS[b] > 0 ? WRITE_WIDTHS[b] : 1) == 0));
`ifndef SYNTHESIS
    initial if (!CONFIG_LEGAL) $fatal(1, "bank_native_router bank %0d invalid geometry", b);
`endif
    localparam logic [ADDR_WIDTH:0] WRITE_LIMIT = (ADDR_WIDTH + 1)'(WRITE_DEPTHS[b]);
    localparam logic [ADDR_WIDTH:0] READ_LIMIT = (ADDR_WIDTH + 1)'(READ_DEPTH);
    wire wr_capable = (wr_req_owner[b] != '0) && WR_CAPABILITIES[b][wr_req_owner[b]];
    wire rd_capable = (rd_req_owner[b] != '0) && RD_CAPABILITIES[b][rd_req_owner[b]];
    wire wr_owned = bank_wr_busy[b] && bank_wr_owner_port[b] == wr_req_owner[b];
    wire rd_owned = bank_rd_busy[b] && bank_rd_owner_port[b] == rd_req_owner[b];
    wire wr_range = {1'b0, wr_req_addr[b]} < WRITE_LIMIT;
    wire rd_range = {1'b0, rd_req_addr[b]} < READ_LIMIT;
    assign wr_req_ready[b] = CONFIG_LEGAL && aresetn && wr_capable && wr_owned && wr_range;
    assign rd_req_ready[b] = CONFIG_LEGAL && aresetn && rd_capable && rd_owned && rd_range;
    assign bank_ena[b] = wr_req_valid[b] && wr_req_ready[b];
    assign bank_addra[b] = wr_req_addr[b];
    assign bank_dina[b] = wr_req_data[b];
    assign bank_wea[b] = wr_req_strb[b];
    assign rd_accept_w[b] = rd_req_valid[b] && rd_req_ready[b];
    assign rd_rsp_valid[b] = aresetn && response_valid_r[MEMORY_READ_LATENCY][b];
    assign rd_rsp_owner[b] = response_owner_r[MEMORY_READ_LATENCY][b];
    assign rd_rsp_data[b] = bank_doutb[b];
  end
  always_comb begin
    bad_request_w = 1'b0;
    bad_code_w = '0;
    for (int b = 0; b < BANK_NUM; b++) begin
      if ((wr_req_valid[b] && !wr_req_ready[b]) || (rd_req_valid[b] && !rd_req_ready[b])) begin
        bad_request_w = 1'b1;
        if (bad_code_w == '0) bad_code_w = 3'd3;
        if ((wr_req_valid[b] && ((wr_req_owner[b] == '0) || !WR_CAPABILITIES[b][wr_req_owner[b]])) ||
            (rd_req_valid[b] && ((rd_req_owner[b] == '0) || !RD_CAPABILITIES[b][rd_req_owner[b]])))
          bad_code_w = 3'd1;
        else if (bad_code_w != 3'd1 &&
                 ((wr_req_valid[b] && (!bank_wr_busy[b] || bank_wr_owner_port[b] != wr_req_owner[b])) ||
                  (rd_req_valid[b] && (!bank_rd_busy[b] || bank_rd_owner_port[b] != rd_req_owner[b]))))
          bad_code_w = 3'd2;
      end
    end
  end
  always_ff @(posedge aclk) begin
    if (!aresetn) begin
      bank_enb   <= '0;
      bank_addrb <= '0;
      for (int p = 0; p <= MEMORY_READ_LATENCY; p++) begin
        response_valid_r[p] <= '0;
        response_owner_r[p] <= '0;
      end
      router_error <= 1'b0;
      router_error_code <= '0;
    end else begin
      bank_enb <= rd_accept_w;
      bank_addrb <= rd_req_addr;
      response_valid_r[0] <= rd_accept_w;
      response_owner_r[0] <= rd_req_owner;
      for (int p = 1; p <= MEMORY_READ_LATENCY; p++) begin
        response_valid_r[p] <= response_valid_r[p-1];
        response_owner_r[p] <= response_owner_r[p-1];
      end
      if (!router_error && bad_request_w) begin
        router_error <= 1'b1;
        router_error_code <= bad_code_w;
      end
    end
  end
endmodule
