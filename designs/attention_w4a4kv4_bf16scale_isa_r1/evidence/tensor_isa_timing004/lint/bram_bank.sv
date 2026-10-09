/* verilator lint_off UNUSED */
/* verilator lint_off UNDRIVEN */
`timescale 1ns/1ps
module bram_bank #(
    parameter integer WRITE_DATA_WIDTH = 128,
    parameter longint unsigned WRITE_DEPTH = 4096,
    parameter integer READ_DATA_WIDTH = 128,
    parameter integer BYTE_WRITE_WIDTH = 8,
    parameter integer READ_LATENCY = 3,
    parameter integer ADDR_WIDTH = 32
) (
    input  logic aclk,
    input  logic aresetn,
    input  logic ena,
    input  logic [(WRITE_DATA_WIDTH/BYTE_WRITE_WIDTH)-1:0] wea,
    input  logic [ADDR_WIDTH-1:0] addra,
    input  logic [WRITE_DATA_WIDTH-1:0] dina,
    input  logic enb,
    input  logic [ADDR_WIDTH-1:0] addrb,
    output logic [READ_DATA_WIDTH-1:0] doutb
);
endmodule
/* verilator lint_on UNDRIVEN */
/* verilator lint_on UNUSED */
