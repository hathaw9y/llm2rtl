module fp32_bf16_epilogue(
 input logic clk,resetn,in_valid,output logic in_ready,
 input logic [127:0] in_sums,in_scales,input logic [3:0] in_mask,input logic [95:0] in_tag,
 output logic out_valid,input logic out_ready,output logic [63:0] out_bf16,
 output logic [3:0] out_mask,output logic [95:0] out_tag,output logic out_error);
 import w8a8_fp32_pkg::*;
 logic [1:0] cv;logic c0ready,c1ready;
 logic [127:0] converted_r,scales0_r,scales1_r;
 logic [127:0] sums_r;
 logic [3:0] mask0_r,mask1_r;logic [95:0] tag0_r,tag1_r;logic [3:0] bad0_r,bad1_r;
 logic [3:0] mr,mv,mnf;logic [31:0] result[0:3];
 logic [15:0] rounded[0:3];logic error_w,round_ready;

 assign c1ready=!cv[1]||(&mr);assign c0ready=!cv[0]||c1ready;assign in_ready=c0ready&resetn;
 always_ff @(posedge clk) begin
   if(!resetn) cv<=0;
   else begin
     if(c0ready) begin
       cv[0]<=in_valid;sums_r<=in_sums;scales0_r<=in_scales;mask0_r<=in_mask;tag0_r<=in_tag;
       for(integer j=0;j<4;j=j+1) bad0_r[j]<=in_scales[j*32+31] || in_scales[j*32+23+:8]==8'hff;
     end
     if(c1ready) begin cv[1]<=cv[0];scales1_r<=scales0_r;mask1_r<=mask0_r;tag1_r<=tag0_r;bad1_r<=bad0_r;
       for(integer j=0;j<4;j=j+1) converted_r[j*32+:32]<=int32_to_fp32(sums_r[j*32+:32]);
     end
   end
 end
 // Additional eight metadata bits need full preservation; parallel tag queue follows identical multiplier stages.
 logic [95:0] tags_r[0:5];logic [3:0] masks_r[0:5],bads_r[0:5];logic [5:0] tv;logic tr[0:5];
 assign tr[5]=!tv[5]||round_ready;
 for(genvar j=0;j<5;j=j+1)begin: tag_ready_chain
 assign tr[j]=round_ready || !( &tv[5:j]);
 end
 always_ff @(posedge clk) begin
   if(!resetn) tv<=0;
   else for(integer j=0;j<6;j=j+1) if(tr[j]) begin
     tv[j]<=(j==0)?cv[1]:tv[j-1];
     if(j==0) begin tags_r[j]<=tag1_r;masks_r[j]<=mask1_r;bads_r[j]<=bad1_r;end
     else begin tags_r[j]<=tags_r[j-1];masks_r[j]<=masks_r[j-1];bads_r[j]<=bads_r[j-1];end
   end
 end
 for(genvar lane=0;lane<4;lane=lane+1) begin: lanes
   w8a8_fp32_mul mul(.clk(clk),.resetn(resetn),.s_valid(cv[1]),.s_ready(mr[lane]),.s_a(converted_r[lane*32+:32]),.s_b(scales1_r[lane*32+:32]),.s_tag(96'd0),.m_valid(mv[lane]),.m_ready(round_ready),.m_result(result[lane]),/* verilator lint_off PINCONNECTEMPTY */ .m_tag(), /* verilator lint_on PINCONNECTEMPTY */.m_nonfinite(mnf[lane]));
   assign rounded[lane]=fp32_to_bf16(result[lane]);
 end
 assign round_ready=!out_valid||out_ready;
 always_comb begin error_w=0;for(integer j=0;j<4;j=j+1) error_w=error_w|(masks_r[5][j]&&(bads_r[5][j]||mnf[j]||rounded[j][14:7]==8'hff));end
 always_ff @(posedge clk) begin
   if(!resetn) begin out_valid<=0;out_error<=0;out_mask<=0;out_tag<=0;out_bf16<=0;end
   else if(round_ready) begin out_valid<=&mv;out_tag<=tags_r[5];out_mask<=masks_r[5];out_error<=error_w;
     for(integer j=0;j<4;j=j+1) out_bf16[j*16+:16]<=rounded[j];
   end
 end
endmodule
