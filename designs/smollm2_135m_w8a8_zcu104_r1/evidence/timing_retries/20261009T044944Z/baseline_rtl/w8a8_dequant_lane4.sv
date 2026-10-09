module w8a8_dequant_lane4(
 input logic clk,resetn,s_valid,output logic s_ready,input logic[31:0]s_int8,
 input logic[127:0]s_scale,input logic[3:0]s_mask,input logic[95:0]s_tag,
 output logic m_valid,input logic m_ready,output logic[63:0]m_bf16,
 output logic[3:0]m_mask,output logic[95:0]m_tag,output logic[3:0]m_error);
 import w8a8_fp32_pkg::*;
 logic pv,pr,ready_w;logic[127:0]converted_r,scale_r;logic[3:0]mask_r,bad_r,mr,mv,nf;
 logic[95:0]tag_r,tags_r[0:5];logic[3:0]masks_r[0:5],bads_r[0:5];logic[5:0]tv;logic tr[0:5];logic[31:0]result[0:3];logic[15:0]rounded[0:3];
 assign pr=!pv||(&mr);assign s_ready=pr&&resetn;assign ready_w=!m_valid||m_ready;
 assign tr[5]=!tv[5]||ready_w;
 for(genvar j=0;j<5;j=j+1)assign tr[j]=ready_w||!( &tv[5:j]);
 for(genvar l=0;l<4;l=l+1)begin:lanes
 w8a8_fp32_mul mul(.clk(clk),.resetn(resetn),.s_valid(pv),.s_ready(mr[l]),.s_a(converted_r[l*32+:32]),.s_b(scale_r[l*32+:32]),.s_tag(96'd0),.m_valid(mv[l]),.m_ready(ready_w),.m_result(result[l]),/* verilator lint_off PINCONNECTEMPTY */.m_tag(),/* verilator lint_on PINCONNECTEMPTY */.m_nonfinite(nf[l]));
 assign rounded[l]=fp32_to_bf16(result[l]);
 end
 always_ff @(posedge clk)begin
 if(!resetn)begin pv<=0;tv<=0;m_valid<=0;m_bf16<=0;m_mask<=0;m_tag<=0;m_error<=0;end
 else begin
 if(pr)begin pv<=s_valid;scale_r<=s_scale;mask_r<=s_mask;tag_r<=s_tag;
 for(integer l=0;l<4;l=l+1)begin converted_r[l*32+:32]<=int32_to_fp32({{24{s_int8[l*8+7]}},s_int8[l*8+:8]});bad_r[l]<=s_int8[l*8+:8]==8'h80||s_scale[l*32+31]||s_scale[l*32+:31]==0||s_scale[l*32+23+:8]==255;end
 end
 for(integer st=0;st<6;st=st+1)if(tr[st])begin tv[st]<=(st==0)?pv:tv[st-1];if(st==0)begin tags_r[st]<=tag_r;masks_r[st]<=mask_r;bads_r[st]<=bad_r;end else begin tags_r[st]<=tags_r[st-1];masks_r[st]<=masks_r[st-1];bads_r[st]<=bads_r[st-1];end end
 if(ready_w)begin m_valid<=&mv;m_tag<=tags_r[5];m_mask<=masks_r[5];for(integer l=0;l<4;l=l+1)begin m_bf16[l*16+:16]<=rounded[l];m_error[l]<=masks_r[5][l]&&(bads_r[5][l]||nf[l]||rounded[l][14:7]==255);end end
 end
 end
endmodule
