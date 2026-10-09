`timescale 1ns/1ps
module audit_command_bram_tb;
logic clk=0,resetn=0,write_allowed=0,start=0,program_wr_valid=0,cmd_enb=0;
logic[3:0]program_wr_address=0,cmd_addrb=0;logic[127:0]program_wr_data=0,cmd_doutb;logic[15:0]program_wr_strb=0;logic program_wr_ready;
smollm2_command_bram dut(.*);
logic[127:0]shadow[0:15];logic[1:0]valid_pipe=0;logic[127:0]data_pipe[0:1];int checks=0,writes=0,cycles=0;
always #2.5 clk=~clk;
always @(posedge clk)begin
 cycles++;
 if(cycles>1000)$fatal(1,"watchdog");
 if(program_wr_ready !== (resetn&&write_allowed&&!start))$fatal(1,"write eligibility differs");
 if(!resetn)valid_pipe=0;
 else begin
  if(valid_pipe[1])begin if(cmd_doutb!==data_pipe[1])$fatal(1,"two-cycle read mismatch got%h expected%h",cmd_doutb,data_pipe[1]);checks++;end
  valid_pipe={valid_pipe[0],cmd_enb};data_pipe[1]=data_pipe[0];if(cmd_enb)data_pipe[0]=shadow[cmd_addrb];
  if(program_wr_valid&&program_wr_ready)begin for(int q=0;q<16;q++)if(program_wr_strb[q])shadow[program_wr_address][q*8+:8]=program_wr_data[q*8+:8];writes++;end
 end
end
task automatic ticks(input int n);repeat(n)@(negedge clk);endtask
task automatic wr(input int a,input logic[127:0]v,input logic[15:0]s);
 program_wr_valid=1;program_wr_address=4'(a);program_wr_data=v;program_wr_strb=s;ticks(1);program_wr_valid=0;
endtask
task automatic rd(input int a);cmd_enb=1;cmd_addrb=4'(a);ticks(1);cmd_enb=0;endtask
initial begin
 ticks(4);resetn=1;write_allowed=1;ticks(1);
 for(int a=0;a<16;a++)wr(a,{32'(a),32'h12345678,32'h89abcdef,32'h55443322},16'hffff);
 for(int a=0;a<16;a++)rd(a);ticks(4);
 for(int a=0;a<16;a++)wr(a,128'hffeeddccbbaa99887766554433221100,16'h5555);
 for(int a=15;a>=0;a--)rd(a);ticks(4);
 start=1;wr(4,0,16'hffff);start=0;rd(4);ticks(4);
 write_allowed=0;wr(7,0,16'hffff);write_allowed=1;rd(7);ticks(4);
 wr(5,0,0);rd(5);ticks(4);
 // Read-first same-edge collision and new payload on following read.
 program_wr_valid=1;program_wr_address=6;program_wr_strb=16'hffff;program_wr_data=128'habcdef0123456789;cmd_enb=1;cmd_addrb=6;ticks(1);program_wr_valid=0;cmd_enb=0;ticks(4);rd(6);ticks(4);
 // Reset cancels pending response, blocks PS write, preserves RAM payload.
 rd(2);resetn=0;program_wr_valid=1;program_wr_address=2;program_wr_strb=16'hffff;program_wr_data=0;ticks(4);program_wr_valid=0;resetn=1;ticks(2);
 for(int a=0;a<16;a++)rd(a);ticks(5);
 if(checks<50||writes!=34)$fatal(1,"coverage mismatch checks%0d writes%0d",checks,writes);
 $display("AUDIT_COMMAND_BRAM_PASS checks=%0d writes=%0d cycles=%0d",checks,writes,cycles);$finish;
end
endmodule
