`timescale 1ns/1ps
module tb_support;
 logic clk=0,rstn=0,push=0,pop=0,empty,full;
 logic [7:0] din=0,dout;
 logic [1:0] count;
 logic uv=0,ur,ov,ol;
 logic [63:0] od;
 logic [7:0] ok;
 always #5 clk=~clk;
 fifo #(.FIFO_DEPTH(3),.DATA_WIDTH(8)) f(
   .aclk(clk),.aresetn(rstn),.push(push),.pop(pop),.din(din),
   .dout(dout),.empty(empty),.full(full),.count(count));
 axis_width_up_converter u(.aclk(clk),.aresetn(rstn),
   .s_axis_tdata(32'h12345678),.s_axis_tkeep(4'hf),.s_axis_tvalid(uv),
   .s_axis_tready(ur),.s_axis_tlast(1'b0),.m_axis_tdata(od),
   .m_axis_tkeep(ok),.m_axis_tvalid(ov),.m_axis_tready(1'b0),.m_axis_tlast(ol));
 task automatic step(input logic p,input logic q,input logic [7:0] d);
   @(negedge clk);push=p;pop=q;din=d;@(posedge clk);#1;
 endtask
 initial begin
   repeat(3) @(negedge clk);
   if(ur!==0) $fatal(1,"ready asserted in reset");
   rstn=1;
   step(1,0,8'h11);step(1,0,8'h22);step(1,0,8'h33);
   if(!full || dout!==8'h11) $fatal(1,"FIFO fill");
   step(1,1,8'h44); // Full FIFO rejects push even with pop; documented API.
   if(count!=2 || dout!==8'h22) $fatal(1,"FIFO full/pop");
   step(1,1,8'h55);
   if(count!=2 || dout!==8'h33) $fatal(1,"FIFO simultaneous/wrap");
   step(0,1,0);if(dout!==8'h55) $fatal(1,"FIFO order");
   step(0,1,0);step(0,1,0);if(!empty) $fatal(1,"FIFO underflow");
   @(negedge clk);push=0;pop=0;uv=1;
   @(posedge clk);@(negedge clk);uv=0;rstn=0;#1;
   if(ur!==0) $fatal(1,"ready asserted on partial-word reset");
   @(posedge clk);@(negedge clk);rstn=1;
   if(ov!==0) $fatal(1,"stale output after reset");
   $display("PASS support FIFO non-power-of-two/full/simultaneous/wrap/reset");$finish;
 end
 initial begin #10000;$fatal(1,"timeout");end
endmodule
