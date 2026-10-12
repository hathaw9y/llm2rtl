// Lint-only interface stubs for the vendor-XPM-backed frozen wrappers.
// XSIM and Vivado synthesis never compile this file.
module bram_bank #(
  parameter integer WRITE_DATA_WIDTH=128, parameter longint unsigned WRITE_DEPTH=4096,
  parameter integer READ_DATA_WIDTH=128, parameter integer BYTE_WRITE_WIDTH=8,
  parameter integer READ_LATENCY=3, parameter integer ADDR_WIDTH=32
)(input logic aclk,aresetn,ena,
  input logic[(WRITE_DATA_WIDTH/BYTE_WRITE_WIDTH)-1:0]wea,input logic[ADDR_WIDTH-1:0]addra,
  input logic[WRITE_DATA_WIDTH-1:0]dina,input logic enb,input logic[ADDR_WIDTH-1:0]addrb,
  output logic[READ_DATA_WIDTH-1:0]doutb);
endmodule
module uram_bank #(
  parameter integer DATA_WIDTH=128, parameter longint unsigned DEPTH=8192,
  parameter integer READ_LATENCY=3, parameter integer ADDR_WIDTH=32
)(input logic aclk,aresetn,ena,input logic[(DATA_WIDTH/8)-1:0]wea,
  input logic[ADDR_WIDTH-1:0]addra,input logic[DATA_WIDTH-1:0]dina,input logic enb,
  input logic[ADDR_WIDTH-1:0]addrb,output logic[DATA_WIDTH-1:0]doutb);
endmodule
