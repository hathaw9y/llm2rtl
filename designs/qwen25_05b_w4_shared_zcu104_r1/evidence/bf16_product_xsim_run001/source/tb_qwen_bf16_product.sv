`timescale 1ns/1ps
module tb_qwen_bf16_product;
 import qwen_fp32_pkg::*;
 logic clk=0,rst_n=0,cmd_valid=0,cmd_ready,cmd_w4=1,rsp_valid,rsp_ready=1,rsp_error;
 logic [9:0] cmd_id=0,rsp_id;
 logic [15:0] cmd_a=0,cmd_b=0;logic [31:0] rsp_data;
 always #2.5 clk=~clk;
 qwen_bf16_product_pipe dut(.*);
 logic [31:0] expected[0:7];logic [9:0] identities[0:7];integer head=0,tail=0,accepted=0,returned=0,ticks=0,index=0;
 function automatic logic [31:0] code_float(input logic[3:0] q);
  case(q)
   0:return 0;1:return 32'h3f800000;2:return 32'h40000000;3:return 32'h40400000;
   4:return 32'h40800000;5:return 32'h40a00000;6:return 32'h40c00000;7:return 32'h40e00000;
   9:return 32'hc0e00000;10:return 32'hc0c00000;11:return 32'hc0a00000;12:return 32'hc0800000;
   13:return 32'hc0400000;14:return 32'hc0000000;15:return 32'hbf800000;default:return 32'h7fc00000;
  endcase
 endfunction
 always @(posedge clk)if(rst_n)begin
  if(rsp_valid && rsp_ready)begin
   if(returned>=accepted || rsp_data!==expected[head] || rsp_id!==identities[head] || rsp_error!==(expected[head][30:23]==255))
    $fatal(1,"product mismatch item%0d got%h expected%h id%0d expectedID%0d err%b expectedErr%b accepted%0d",returned,rsp_data,expected[head],rsp_id,identities[head],rsp_error,(expected[head][30:23]==255),accepted);
   head=(head+1)%8;returned=returned+1;
  end
  if(cmd_valid && cmd_ready)begin
   expected[tail]=fp_mul(from_bf16(cmd_a),cmd_w4?code_float(cmd_b[3:0]):from_bf16(cmd_b));
   identities[tail]=cmd_id;tail=(tail+1)%8;accepted=accepted+1;
  end
 end
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  // Exhaustive65536 BF16 patterns x all16 INT4 encodings, including
  // zero/subnormal/nonfinite and reserved -8. Streaming with output stalls.
  while(index<1048576)begin
   @(negedge clk);ticks=ticks+1;rsp_ready=(ticks%19!=0 && ticks%19!=1);#0.1;
   if(cmd_ready)begin cmd_valid=1;cmd_a=16'(index>>4);cmd_b=16'(index&15);cmd_id=10'(index);index=index+1;end
   else cmd_valid=0;
  end
  @(negedge clk);cmd_valid=0;rsp_ready=1;wait(returned==accepted);
  $display("PASS BF16xINT4 exhaustive %0d products with streaming/backpressure",returned);
  index=0;
  while(index<131072)begin
   @(negedge clk);ticks=ticks+1;rsp_ready=(ticks%23!=0);#0.1;
   if(cmd_ready)begin cmd_valid=1;cmd_w4=0;cmd_a=16'(index);cmd_b=index<65536?16'(65535-index):16'((index*1103515245+12345)>>7);cmd_id=10'(index);index=index+1;end
   else cmd_valid=0;
  end
  @(negedge clk);cmd_valid=0;rsp_ready=1;wait(returned==accepted);
  $display("PASS BF16xBF16 %0d additional products",131072);
  @(negedge clk);cmd_valid=1;repeat(3)@(negedge clk);rst_n=0;cmd_valid=0;repeat(2)@(negedge clk);rst_n=1;#1;
  if(rsp_valid || !cmd_ready)$fatal(1,"product reset flush");
  $display("PASS native BF16 product payload/error/ID/backpressure/reset");$finish;
 end
 initial begin #100000000;$fatal(1,"product timeout");end
endmodule
