`timescale 1ns/1ps
module tb_qwen_control_regs;
 logic clk=0;always #2.5 clk=~clk;logic rst_n=0;
 logic [15:0] s_axi_awaddr,s_axi_araddr;logic [2:0] s_axi_awprot,s_axi_arprot;
 logic s_axi_awvalid,s_axi_awready,s_axi_wvalid,s_axi_wready,s_axi_bvalid,s_axi_bready,s_axi_arvalid,s_axi_arready,s_axi_rvalid,s_axi_rready;
 logic [31:0] s_axi_wdata,s_axi_rdata;logic [3:0] s_axi_wstrb;logic [1:0] s_axi_bresp,s_axi_rresp;
 logic busy,done,error,command_mutation,start,accelerator_resetn;logic [7:0] error_code,load_error_code,store_error_code;logic [9:0] pc;
 logic [31:0] captured;integer starts;
 qwen_control_regs dut(.*);
 always @(posedge clk)if(start)starts=starts+1;
 task automatic write(input logic [31:0] value,input logic [1:0] expected_response);
  @(negedge clk);s_axi_awaddr=0;s_axi_awvalid=1;while(!s_axi_awready)@(negedge clk);@(negedge clk);s_axi_awvalid=0;
  repeat(3)@(negedge clk);s_axi_wdata=value;s_axi_wstrb=4'hf;s_axi_wvalid=1;while(!s_axi_wready)@(negedge clk);@(negedge clk);s_axi_wvalid=0;
  while(!s_axi_bvalid)@(negedge clk);if(s_axi_bresp!=expected_response)$fatal(1,"write response");
  repeat(3)begin @(negedge clk);if(!s_axi_bvalid || s_axi_bresp!=expected_response)$fatal(1,"write response hold");end
  s_axi_bready=1;@(negedge clk);s_axi_bready=0;
 endtask
 task automatic read(input logic [15:0] address);
  @(negedge clk);s_axi_araddr=address;s_axi_arvalid=1;while(!s_axi_arready)@(negedge clk);@(negedge clk);s_axi_arvalid=0;
  while(!s_axi_rvalid)@(negedge clk);captured=s_axi_rdata;
  repeat(3)begin @(negedge clk);if(!s_axi_rvalid || s_axi_rdata!=captured)$fatal(1,"read hold");end
  s_axi_rready=1;@(negedge clk);s_axi_rready=0;
 endtask
 initial begin
  s_axi_awaddr=0;s_axi_araddr=0;s_axi_awprot=0;s_axi_arprot=0;s_axi_awvalid=0;s_axi_wvalid=0;s_axi_bready=0;s_axi_arvalid=0;s_axi_rready=0;s_axi_wdata=0;s_axi_wstrb=0;busy=0;done=0;error=0;error_code=0;load_error_code=0;store_error_code=0;pc=0;command_mutation=0;starts=0;
  repeat(4)@(negedge clk);rst_n=1;repeat(17)@(negedge clk);if(!accelerator_resetn)$fatal(1,"power-on reset release");
  read(16'h18);if(captured!=32'h51574e31)$fatal(1,"identity");write(1,0);if(starts!=1)$fatal(1,"START pulse");
  busy=1;repeat(8)@(negedge clk);write(1,2'b10);if(starts!=1)$fatal(1,"start accepted while busy");
  busy=0;done=1;repeat(2)@(negedge clk);read(4);if(!captured[1])$fatal(1,"DONE latch");read(16'h10);if(captured!=1)$fatal(1,"completion count");
  write(1,0);read(4);if(captured[1] || starts!=2)$fatal(1,"stale DONE exposed on restart");done=0;repeat(3)@(negedge clk);done=1;repeat(3)@(negedge clk);read(16'h10);if(captured!=2)$fatal(1,"second completion");
  error=1;error_code=8'h20;repeat(2)@(negedge clk);read(4);if(!captured[2] || captured[15:8]!=8'h20)$fatal(1,"error latch");write(1,2'b10);
  error=0;done=0;write(2,0);if(accelerator_resetn)$fatal(1,"soft reset was not asserted");repeat(17)@(negedge clk);if(!accelerator_resetn)$fatal(1,"soft reset duration");read(4);if(captured[3:1]!=0)$fatal(1,"reset latches");
  command_mutation=1;@(negedge clk);command_mutation=0;read(4);if(!captured[2] || captured[15:8]!=8'he1)$fatal(1,"mutation fault");
  $display("PASS AXI control: independent AW/W, held B/R responses, START/DONE restart, busy/error rejection, coordinated reset, mutation fault");$finish;
 end
endmodule
