`timescale 1ns/1ps
module smollm2_command_bram (
 input logic clk, resetn, write_allowed, start, program_wr_valid,
 input logic [3:0] program_wr_address,
 input logic [127:0] program_wr_data,
 input logic [15:0] program_wr_strb,
 input logic cmd_enb,
 input logic [3:0] cmd_addrb,
 output logic program_wr_ready,
 output logic [127:0] cmd_doutb
);
 assign program_wr_ready=resetn&&write_allowed&&!start;
 bram_bank #(.WRITE_DATA_WIDTH(128),.WRITE_DEPTH(16),.READ_DATA_WIDTH(128),
   .BYTE_WRITE_WIDTH(8),.READ_LATENCY(2),.ADDR_WIDTH(4)) u_program_memory (
   .aclk(clk),.aresetn(resetn),.ena(program_wr_valid&&program_wr_ready),
   .wea(program_wr_strb),.addra(program_wr_address),.dina(program_wr_data),
   .enb(cmd_enb),.addrb(cmd_addrb),.doutb(cmd_doutb));
endmodule
