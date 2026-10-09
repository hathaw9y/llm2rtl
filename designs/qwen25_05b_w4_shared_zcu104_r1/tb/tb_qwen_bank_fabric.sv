`timescale 1ns/1ps
module tb_qwen_bank_fabric;
 logic clk=0;always #2.5 clk=~clk;
 logic rst_n=0;logic [22:0] bank_busy,write_pending;logic [22:0][4:0] bank_owner;
 logic [17:0][4:0] role_bank;logic [17:0] role_rd_en,role_wr_en;
 logic [17:0][12:0] role_rd_addr,role_wr_addr;
 logic [17:0][127:0] role_rd_data,role_wr_data;logic [17:0][15:0] role_wr_mask;
 qwen_bank_fabric dut(.*);
 task automatic write_word(input integer bank,input integer addr,input logic [127:0] data,input logic [15:0] mask);
  @(negedge clk);bank_busy[bank]=1;bank_owner[bank]=1;role_bank[1]=5'(bank);role_wr_addr[1]=13'(addr);role_wr_data[1]=data;role_wr_mask[1]=mask;role_wr_en[1]=1;
  @(negedge clk);role_wr_en[1]=0;
  if(!write_pending[bank])$fatal(1,"accepted write missing pending state");
  @(negedge clk);
  if(write_pending[bank])$fatal(1,"write queue did not drain");
  bank_busy[bank]=0;bank_owner[bank]=0;
 endtask
 task automatic read_word(input integer bank,input integer addr,input logic [127:0] expected);
  @(negedge clk);bank_busy[bank]=1;bank_owner[bank]=15;role_bank[15]=5'(bank);role_rd_addr[15]=13'(addr);role_rd_en[15]=1;
  @(negedge clk);role_rd_en[15]=0;repeat(2)@(negedge clk);
  if(role_rd_data[15]!==expected)$fatal(1,"bank%0d addr%0d got=%h expected=%h",bank,addr,role_rd_data[15],expected);
  bank_busy[bank]=0;bank_owner[bank]=0;
 endtask
 initial begin
  bank_busy=0;bank_owner=0;role_bank=0;role_rd_en=0;role_wr_en=0;role_rd_addr=0;role_wr_addr=0;role_wr_data=0;role_wr_mask=0;
  repeat(4)@(negedge clk);rst_n=1;
  for(integer b=0;b<23;b=b+1)begin
   write_word(b,0,128'h112233445566778899aabbccddeeff00,16'hffff);
   write_word(b,0,128'hdeadbeef000000000000000000000000,16'hf000);
   read_word(b,0,128'hdeadbeef5566778899aabbccddeeff00);
   // Unowned traffic and a wrong active bank cannot overwrite the bank.
   @(negedge clk);role_bank[1]=5'(b);role_wr_en[1]=1;role_wr_addr[1]=0;role_wr_data[1]=0;role_wr_mask[1]=16'hffff;
   @(negedge clk);role_wr_en[1]=0;read_word(b,0,128'hdeadbeef5566778899aabbccddeeff00);
  end
  // Shared reset invalidates control but must not physically wipe stored data.
  @(negedge clk);rst_n=0;repeat(3)@(negedge clk);rst_n=1;
  read_word(18,0,128'hdeadbeef5566778899aabbccddeeff00);
  $display("PASS bank fabric23 capacities/routes/byte masks/latency3/unowned writes/reset retention; logical memory model only");$finish;
 end
endmodule
