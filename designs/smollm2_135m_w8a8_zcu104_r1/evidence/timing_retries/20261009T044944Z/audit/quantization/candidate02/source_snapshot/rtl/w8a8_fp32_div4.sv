// Nineteen-stage exact restoring FP32 divider; no reciprocal, global elastic freeze.
module w8a8_fp32_div4(
 input logic clk,resetn,s_valid,output logic s_ready,
 input logic [127:0] s_a,s_b,input logic [3:0] s_mask,input logic [95:0] s_tag,
 output logic m_valid,input logic m_ready,output logic [127:0] m_result,
 output logic [3:0] m_mask,output logic [95:0] m_tag,
 output logic [3:0] m_invalid,m_overflow);
 logic [18:0] valid_r;logic advance_w;
 logic [95:0] tags_r[0:18];logic [3:0] masks_r[0:18];
 logic sign_r[0:18][0:3],zero_r[0:18][0:3],invalid_r[0:18][0:3];
 logic signed [10:0] exponent_r[0:18][0:3];
 logic [23:0] a_r[0:1][0:3],b_r[0:15][0:3];
 logic [24:0] remainder_r[0:15][0:3];logic [26:0] quotient_r[0:15][0:3];
 logic [24:0] aligned_r[0:3],rounded_r[0:3];logic guard_r[0:3],sticky_r[0:3];
 logic [127:0] results_r;logic [3:0] overflow_r;
 assign advance_w=!valid_r[18]||m_ready;assign s_ready=advance_w&&resetn;
 assign m_valid=valid_r[18];assign m_result=results_r;
 assign m_mask=masks_r[18];assign m_tag=tags_r[18];assign m_overflow=overflow_r&masks_r[18];
 for(genvar l=0;l<4;l=l+1) assign m_invalid[l]=invalid_r[18][l]&&masks_r[18][l];
 always_ff @(posedge clk) begin
  if(!resetn)begin valid_r<=0;results_r<=0;overflow_r<=0;end
  else if(advance_w)begin
   valid_r<={valid_r[17:0],s_valid};
   for(integer st=0;st<19;st=st+1)begin
    if(st==0)begin tags_r[st]<=s_tag;masks_r[st]<=s_mask;end
    else begin tags_r[st]<=tags_r[st-1];masks_r[st]<=masks_r[st-1];end
    for(integer l=0;l<4;l=l+1)begin
     if(st==0)begin
      sign_r[st][l]<=s_a[l*32+31]^s_b[l*32+31];zero_r[st][l]<=s_a[l*32+:31]==0;
      invalid_r[st][l]<=s_a[l*32+23+:8]==255||s_b[l*32+23+:8]==255||s_b[l*32+:31]==0;
     end else begin sign_r[st][l]<=sign_r[st-1][l];zero_r[st][l]<=zero_r[st-1][l];invalid_r[st][l]<=invalid_r[st-1][l];end
    end
   end
   for(integer l=0;l<4;l=l+1)begin : arithmetic
    integer pa,pb,shift_count;logic[23:0] na,nb;logic signed[10:0] ea,eb;
    logic[24:0] rem,trial;logic[26:0] quo;logic[24:0] aligned;
    logic guard_bit,sticky_bit;logic signed[10:0] final_exp;logic[24:0] final_mant;logic[31:0] packed_result;
    a_r[0][l]<={s_a[l*32+23+:8]!=0,s_a[l*32+:23]};
    b_r[0][l]<={s_b[l*32+23+:8]!=0,s_b[l*32+:23]};
    ea=(s_a[l*32+23+:8]==0)?-11'sd126:11'({1'b0,s_a[l*32+23+:8]})-11'sd127;
    eb=(s_b[l*32+23+:8]==0)?-11'sd126:11'({1'b0,s_b[l*32+23+:8]})-11'sd127;
    // Capture independent decoded exponents in stage0 (difference adjusted during normalize).
    exponent_r[0][l]<=ea-eb;
    na=a_r[0][l];nb=b_r[0][l];pa=23;pb=23;
    for(integer bitnum=0;bitnum<24;bitnum=bitnum+1)begin if(na[bitnum])pa=bitnum;if(nb[bitnum])pb=bitnum;end
    a_r[1][l]<=na<<(23-pa);b_r[1][l]<=nb<<(23-pb);
    exponent_r[1][l]<=exponent_r[0][l]+11'(pa-pb);
    if(a_r[1][l]<b_r[1][l])begin
     remainder_r[2][l]<={a_r[1][l],1'b0}-{1'b0,b_r[1][l]};
     exponent_r[2][l]<=exponent_r[1][l]-11'sd1;
    end else begin remainder_r[2][l]<={1'b0,a_r[1][l]}-{1'b0,b_r[1][l]};exponent_r[2][l]<=exponent_r[1][l];end
    b_r[2][l]<=b_r[1][l];quotient_r[2][l]<=27'd1;
    for(integer st=3;st<16;st=st+1)begin
     rem=remainder_r[st-1][l];quo=quotient_r[st-1][l];
     for(integer bitstep=0;bitstep<2;bitstep=bitstep+1)begin
      trial=rem<<1;
      if(trial>={1'b0,b_r[st-1][l]})begin rem=trial-{1'b0,b_r[st-1][l]};quo={quo[25:0],1'b1};end
      else begin rem=trial;quo={quo[25:0],1'b0};end
     end
     remainder_r[st][l]<=rem;quotient_r[st][l]<=quo;b_r[st][l]<=b_r[st-1][l];exponent_r[st][l]<=exponent_r[st-1][l];
    end
    shift_count=(exponent_r[15][l]<-11'sd126)?3+(-126-integer'(exponent_r[15][l])):3;
    aligned=0;guard_bit=0;sticky_bit=remainder_r[15][l]!=0;
    if(shift_count<=27)begin aligned=25'(quotient_r[15][l]>>shift_count);guard_bit=quotient_r[15][l][shift_count-1];end
    for(integer bitnum=0;bitnum<27;bitnum=bitnum+1)if(bitnum<shift_count-1)sticky_bit=sticky_bit|quotient_r[15][l][bitnum];
    aligned_r[l]<=aligned;guard_r[l]<=guard_bit;sticky_r[l]<=sticky_bit;exponent_r[16][l]<=exponent_r[15][l];
    rounded_r[l]<=aligned_r[l]+{24'd0,(guard_r[l]&&(sticky_r[l]||aligned_r[l][0]))};exponent_r[17][l]<=exponent_r[16][l];
    final_exp=exponent_r[17][l];final_mant=rounded_r[l];
    if(final_mant[24])begin final_mant=final_mant>>1;final_exp=final_exp+11'sd1;end
    packed_result={sign_r[17][l],31'd0};overflow_r[l]<=0;
    if(invalid_r[17][l])packed_result=32'h7fc00000;
    else if(!zero_r[17][l])begin
     if(final_exp>11'sd127)begin packed_result={sign_r[17][l],8'hff,23'd0};overflow_r[l]<=1;end
     else if(exponent_r[17][l]<-11'sd126)packed_result={sign_r[17][l],7'd0,final_mant[23:0]};
     else packed_result={sign_r[17][l],8'(final_exp+11'sd127),final_mant[22:0]};
    end
    results_r[l*32+:32]<=packed_result;exponent_r[18][l]<=final_exp;
   end
  end
 end
endmodule
