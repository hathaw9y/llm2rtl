`timescale 1ns/1ps
module bank_native_memories #(
    parameter int BANK_NUM = 2,
    parameter int ADDR_WIDTH = 32,
    parameter int MAX_DATA_WIDTH = 128,
    parameter int MEMORY_READ_LATENCY = 3,
    parameter int MEMORY_TYPES [0:BANK_NUM-1] = '{default:1},
    parameter int WRITE_WIDTHS [0:BANK_NUM-1] = '{default:128},
    parameter int READ_WIDTHS [0:BANK_NUM-1] = '{default:128},
    parameter longint unsigned WRITE_DEPTHS [0:BANK_NUM-1] = '{default:64}
) (
    input logic aclk, aresetn,
    input logic [BANK_NUM-1:0] bank_ena, bank_enb,
    input logic [BANK_NUM-1:0][MAX_DATA_WIDTH/8-1:0] bank_wea,
    input logic [BANK_NUM-1:0][ADDR_WIDTH-1:0] bank_addra, bank_addrb,
    input logic [BANK_NUM-1:0][MAX_DATA_WIDTH-1:0] bank_dina,
    output logic [BANK_NUM-1:0][MAX_DATA_WIDTH-1:0] bank_doutb
);
  for (genvar b=0; b<BANK_NUM; b++) begin : g_bank
    logic [READ_WIDTHS[b]-1:0] doutb_w;
    assign bank_doutb[b] = MAX_DATA_WIDTH'(doutb_w);
    localparam logic WIDTHS_LEGAL = WRITE_WIDTHS[b] > 0 && READ_WIDTHS[b] > 0 &&
        WRITE_WIDTHS[b] <= MAX_DATA_WIDTH && READ_WIDTHS[b] <= MAX_DATA_WIDTH &&
        WRITE_WIDTHS[b] % 8 == 0 && READ_WIDTHS[b] % 8 == 0;
    if (MEMORY_TYPES[b] == 1 && WIDTHS_LEGAL) begin : g_bram
      bram_bank #(.WRITE_DATA_WIDTH(WRITE_WIDTHS[b]), .READ_DATA_WIDTH(READ_WIDTHS[b]),
          .WRITE_DEPTH(WRITE_DEPTHS[b]), .READ_LATENCY(MEMORY_READ_LATENCY), .ADDR_WIDTH(ADDR_WIDTH)) u_memory (
          .aclk(aclk), .aresetn(aresetn), .ena(bank_ena[b]), .enb(bank_enb[b]),
          .wea(bank_wea[b][WRITE_WIDTHS[b]/8-1:0]), .addra(bank_addra[b]),
          .addrb(bank_addrb[b]), .dina(bank_dina[b][WRITE_WIDTHS[b]-1:0]), .doutb(doutb_w));
    end else if (MEMORY_TYPES[b] == 2 && WIDTHS_LEGAL && WRITE_WIDTHS[b] == READ_WIDTHS[b]) begin : g_uram
      uram_bank #(.DATA_WIDTH(WRITE_WIDTHS[b]), .DEPTH(WRITE_DEPTHS[b]),
          .READ_LATENCY(MEMORY_READ_LATENCY), .ADDR_WIDTH(ADDR_WIDTH)) u_memory (
          .aclk(aclk), .aresetn(aresetn), .ena(bank_ena[b]), .enb(bank_enb[b]),
          .wea(bank_wea[b][WRITE_WIDTHS[b]/8-1:0]), .addra(bank_addra[b]),
          .addrb(bank_addrb[b]), .dina(bank_dina[b][WRITE_WIDTHS[b]-1:0]), .doutb(doutb_w));
    end else begin : g_invalid
      assign doutb_w = '0;
`ifndef SYNTHESIS
      initial $fatal(1, "bank_native_memories bank %0d unsupported type/width (URAM requires equal widths)", b);
`endif
    end
  end
endmodule
