`timescale 1ns/1ps
module command_bram_tb;
 logic clk=0,resetn=0,write_allowed=1,start=0,program_wr_valid=0,cmd_enb=0;
 logic [3:0] program_wr_address=0,cmd_addrb=0;
 logic [127:0] program_wr_data=0,cmd_doutb;
 logic [15:0] program_wr_strb=0;
 logic program_wr_ready;
 logic [127:0] golden[16];
 integer checks=0;
 smollm2_command_bram dut(.*);
 always #2.5 clk=~clk;
 task automatic wr(input integer address,input logic[127:0] data,input logic[15:0] mask,input logic allowed,input logic starting);
 begin
 @(negedge clk);program_wr_valid=1;program_wr_address=4'(address);program_wr_data=data;program_wr_strb=mask;write_allowed=allowed;start=starting;
 #0.1;if(program_wr_ready!==(resetn&&allowed&&!starting))$fatal(1,"write ready priority");
 @(posedge clk);if(program_wr_ready)for(integer b=0;b<16;b++)if(mask[b])golden[address][b*8+:8]=data[b*8+:8];
 @(negedge clk);program_wr_valid=0;start=0;write_allowed=1;
 end
 endtask
 task automatic rd(input integer address);
 begin
 @(negedge clk);cmd_enb=1;cmd_addrb=4'(address);
 @(posedge clk);#0.1;
 @(negedge clk);cmd_enb=0;
 @(posedge clk);#0.1;
 if(cmd_doutb!==golden[address])$fatal(1,"2cycle read addr%0d got%h exp%h",address,cmd_doutb,golden[address]);
 checks++;
 end
 endtask
 initial begin
 repeat(3)@(negedge clk);resetn=1;
 for(integer a=0;a<16;a++)begin golden[a]=0;wr(a,{4{32'h12345678+32'(a)}},16'hffff,1,0);end
 for(integer a=0;a<16;a++)rd(a);
 for(integer a=0;a<16;a++)begin
 wr(a,{4{32'h76543210+32'(a)}},16'h5555,1,0);rd(a);
 wr(a,'1,16'hffff,0,0);rd(a);wr(a,'1,16'hffff,1,1);rd(a);
 wr(a,'1,16'h0000,1,0);rd(a);
 end
 // Reset zeros the read pipeline while preserving command payload.
 @(negedge clk);resetn=0;repeat(3)@(posedge clk);#0.1;if(cmd_doutb!==0)$fatal(1,"read reset");
 @(negedge clk);resetn=1;for(integer a=0;a<16;a++)rd(a);
 // Consecutive fixed-latency requests, with distinct records on each edge.
 @(negedge clk);cmd_enb=1;cmd_addrb=0;
 @(posedge clk);@(negedge clk);cmd_addrb=1;
 @(posedge clk);#0.1;if(cmd_doutb!==golden[0])$fatal(1,"pipelined first");
 for(integer a=2;a<16;a++)begin @(negedge clk);cmd_addrb=4'(a);@(posedge clk);#0.1;if(cmd_doutb!==golden[a-1])$fatal(1,"pipelined record");checks++;end
 @(negedge clk);cmd_enb=0;@(posedge clk);#0.1;if(cmd_doutb!==golden[15])$fatal(1,"pipelined last");
 $display("COMMAND_BRAM_PASS checks=%0d",checks);$finish;
 end
 initial begin #100000;$fatal(1,"timeout");end
endmodule
