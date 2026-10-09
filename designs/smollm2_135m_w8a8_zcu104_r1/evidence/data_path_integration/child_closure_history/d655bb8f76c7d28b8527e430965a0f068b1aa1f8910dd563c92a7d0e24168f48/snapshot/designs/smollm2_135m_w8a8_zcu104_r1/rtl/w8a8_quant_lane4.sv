module w8a8_quant_lane4(
 input logic clk,resetn,s_valid,output logic s_ready,input logic[63:0]s_bf16,
 input logic[127:0]s_scale,input logic s_unsigned,input logic[3:0]s_mask,input logic[95:0]s_tag,
 output logic m_valid,input logic m_ready,output logic[31:0]m_int8,
 output logic[127:0]m_quotient,output logic[3:0]m_mask,output logic[95:0]m_tag,output logic[3:0]m_error);
 logic pv,pr,dr,dv;logic[127:0]a_r,b_r,dresult;logic[3:0]mask_r,bad_r,dmask,dinvalid,doverflow;
 logic[95:0]tag_r,dtag;logic unsigned_r;
 logic[3:0]bad_pipe[0:18];logic unsigned_pipe[0:18];
 logic[127:0]quotient_r;logic cvalid,c_ready,out_ready_w;logic[3:0]c_mask,c_error,c_sign,c_guard,c_sticky;
 logic[7:0]c_base[0:3];logic[95:0]c_tag;
 assign pr=!pv||dr;assign s_ready=pr&&resetn;assign c_ready=!cvalid||out_ready_w;assign out_ready_w=!m_valid||m_ready;
 w8a8_fp32_div4 div(.clk(clk),.resetn(resetn),.s_valid(pv),.s_ready(dr),.s_a(a_r),.s_b(b_r),.s_mask(mask_r),.s_tag(tag_r),.m_valid(dv),.m_ready(c_ready),.m_result(dresult),.m_mask(dmask),.m_tag(dtag),.m_invalid(dinvalid),.m_overflow(doverflow));
 always_ff @(posedge clk)begin
  if(!resetn)begin pv<=0;cvalid<=0;m_valid<=0;m_int8<=0;m_quotient<=0;m_error<=0;m_mask<=0;m_tag<=0;end
  else begin
   if(pr)begin pv<=s_valid;b_r<=s_scale;mask_r<=s_mask;tag_r<=s_tag;unsigned_r<=s_unsigned;
    for(integer l=0;l<4;l=l+1)begin a_r[l*32+:32]<={s_bf16[l*16+:16],16'd0};bad_r[l]<=s_bf16[l*16+7+:8]==255||s_scale[l*32+31]||s_scale[l*32+:31]==0||s_scale[l*32+23+:8]==255;end
   end
   if(dr)begin
    bad_pipe[0]<=bad_r;unsigned_pipe[0]<=unsigned_r;
    for(integer st=1;st<19;st=st+1)begin bad_pipe[st]<=bad_pipe[st-1];unsigned_pipe[st]<=unsigned_pipe[st-1];end
   end
   if(c_ready)begin
    cvalid<=dv;quotient_r<=dresult;c_mask<=dmask;c_tag<=dtag;c_error<=(bad_pipe[18]|dinvalid)&dmask;
    for(integer l=0;l<4;l=l+1)begin : clip
     logic[31:0]x;logic[7:0]base;logic guard_bit,sticky_bit,negative;integer exponent,shift_count;
     x=dresult[l*32+:32];negative=x[31];base=0;guard_bit=0;sticky_bit=0;
     if(unsigned_pipe[18]&&negative)negative=0;
     else if(x[30:0]>=31'h42fe0000)base=8'd127;
     else begin
      exponent=integer'({1'b0,x[30:23]})-127;
      if(exponent>=0)begin
       shift_count=23-exponent;base=8'({1'b1,x[22:0]}>>shift_count);guard_bit=x[shift_count-1];
       for(integer bitnum=0;bitnum<23;bitnum=bitnum+1)if(bitnum<shift_count-1)sticky_bit=sticky_bit|x[bitnum];
      end else if(exponent==-1)begin guard_bit=1;sticky_bit=|x[22:0];end
     end
     c_base[l]<=base;c_sign[l]<=negative;c_guard[l]<=guard_bit;c_sticky[l]<=sticky_bit;
    end
   end
   if(out_ready_w)begin m_valid<=cvalid;m_quotient<=quotient_r;m_mask<=c_mask;m_tag<=c_tag;m_error<=c_error;
    for(integer l=0;l<4;l=l+1)begin : integer_round
     logic[7:0]magnitude;magnitude=c_base[l]+{7'd0,(c_guard[l]&&(c_sticky[l]||c_base[l][0]))};
     m_int8[l*8+:8]<=c_sign[l]?(~magnitude+8'd1):magnitude;
    end
   end
  end
 end
 // Overflow is deliberately consumed as saturation through its Inf result, never as numerical error.
 logic unused_overflow;assign unused_overflow=|doverflow;
endmodule
