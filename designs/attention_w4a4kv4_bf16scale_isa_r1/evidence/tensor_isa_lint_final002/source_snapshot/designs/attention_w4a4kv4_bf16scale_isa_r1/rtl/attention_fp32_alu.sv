module attention_fp32_alu(
 input logic aclk,aresetn,input logic cmd_valid,output logic cmd_ready,
 input logic [15:0] cmd_id,input logic [2:0] cmd_op,input logic [31:0] cmd_a,cmd_b,
 output logic resp_valid,input logic resp_ready,output logic [15:0] resp_id,
 output logic [31:0] resp_data,output logic resp_error
);
 typedef enum logic [3:0] {IDLE,ALIGN,SUM,PRODUCT,DIV_NORM,DIVIDE,PACK,ROUND,ENCODE,RESPONSE} state_t;
 state_t state_r;
 // ADD/SUB operands are exact integers in units of 2^-149: at most 278 bits.
 // Serial placement and packing retain all cancellation and subnormal information.
 logic [287:0] mag_r,a_r,b_r;
 logic [23:0] ma_r,mb_r;
 logic [8:0] ashift_r,bshift_r;
 logic signed [10:0] power_r,ea_r,eb_r;
 logic sign_r,sa_r,sb_r,guard_r,sticky_r;
 logic [51:0] dividend_r;
 logic [50:0] quotient_r;
 logic [23:0] remainder_r;
 logic [5:0] div_count_r;
 logic [24:0] div_trial;
 logic [24:0] rounded;
 logic [7:0] encoded_exp;
 assign cmd_ready=aresetn && state_r==IDLE;
 assign resp_valid=state_r==RESPONSE;
 assign div_trial={remainder_r[23:0],dividend_r[51]};
 assign rounded={1'b0,mag_r[23:0]}+25'(guard_r && (sticky_r || mag_r[0]));
 assign encoded_exp=8'(power_r+11'sd150);
 always_ff @(posedge aclk) begin
  if(!aresetn) begin
   state_r<=IDLE;resp_id<=0;resp_data<=0;resp_error<=0;
   mag_r<=0;a_r<=0;b_r<=0;ma_r<=0;mb_r<=0;ashift_r<=0;bshift_r<=0;
   power_r<=0;ea_r<=0;eb_r<=0;sign_r<=0;sa_r<=0;sb_r<=0;guard_r<=0;sticky_r<=0;
   dividend_r<=0;quotient_r<=0;remainder_r<=0;div_count_r<=0;
  end else case(state_r)
   IDLE:if(cmd_valid && cmd_ready) begin
    resp_id<=cmd_id;resp_error<=0;resp_data<=0;guard_r<=0;sticky_r<=0;
    ma_r<=cmd_a[30:23]==0?{1'b0,cmd_a[22:0]}:{1'b1,cmd_a[22:0]};
    mb_r<=cmd_b[30:23]==0?{1'b0,cmd_b[22:0]}:{1'b1,cmd_b[22:0]};
    ea_r<=cmd_a[30:23]==0?-11'sd149:$signed({3'b0,cmd_a[30:23]})-11'sd150;
    eb_r<=cmd_b[30:23]==0?-11'sd149:$signed({3'b0,cmd_b[30:23]})-11'sd150;
    sa_r<=cmd_a[31];sb_r<=cmd_b[31]^(cmd_op==4);sign_r<=cmd_a[31]^cmd_b[31];
    if(cmd_op==3) begin
     mag_r<={256'b0,(cmd_a[31]?(~cmd_a+32'd1):cmd_a)};power_r<=0;sign_r<=cmd_a[31];state_r<=PACK;
    end else if(cmd_op>4 || cmd_a[30:23]==255 || cmd_b[30:23]==255 || (cmd_op==2 && cmd_b[30:0]==0)) begin
     resp_error<=1;state_r<=RESPONSE;
    end else if(cmd_op==0 || cmd_op==4) begin
     a_r<={264'b0,(cmd_a[30:23]==0?{1'b0,cmd_a[22:0]}:{1'b1,cmd_a[22:0]})};
     b_r<={264'b0,(cmd_b[30:23]==0?{1'b0,cmd_b[22:0]}:{1'b1,cmd_b[22:0]})};
     ashift_r<=cmd_a[30:23]==0?0:{1'b0,cmd_a[30:23]}-9'd1;
     bshift_r<=cmd_b[30:23]==0?0:{1'b0,cmd_b[30:23]}-9'd1;
     power_r<=-149;state_r<=ALIGN;
    end else if(cmd_a[30:0]==0 || (cmd_op==1 && cmd_b[30:0]==0)) begin
     resp_data<={cmd_a[31]^cmd_b[31],31'b0};state_r<=RESPONSE;
    end else state_r<=cmd_op==1?PRODUCT:DIV_NORM;
   end
   ALIGN:begin
    if(ashift_r!=0) begin a_r<=a_r<<1;ashift_r<=ashift_r-1'b1;end
    if(bshift_r!=0) begin b_r<=b_r<<1;bshift_r<=bshift_r-1'b1;end
    if(ashift_r==0 && bshift_r==0) state_r<=SUM;
   end
   SUM:begin
    if(sa_r==sb_r) begin mag_r<=a_r+b_r;sign_r<=sa_r;end
    else if(a_r>b_r) begin mag_r<=a_r-b_r;sign_r<=sa_r;end
    else if(b_r>a_r) begin mag_r<=b_r-a_r;sign_r<=sb_r;end
    else begin mag_r<=0;sign_r<=0;end
    state_r<=PACK;
   end
   PRODUCT:begin mag_r<={240'b0,(48'(ma_r)*48'(mb_r))};power_r<=ea_r+eb_r;state_r<=PACK;end
   DIV_NORM:begin
    if(!ma_r[23]) begin ma_r<=ma_r<<1;ea_r<=ea_r-1'b1;end
    if(!mb_r[23]) begin mb_r<=mb_r<<1;eb_r<=eb_r-1'b1;end
    if(ma_r[23] && mb_r[23]) begin
     dividend_r<={1'b0,ma_r,27'b0};remainder_r<=0;quotient_r<=0;div_count_r<=52;
     power_r<=ea_r-eb_r-11'sd27;state_r<=DIVIDE;
    end
   end
   // 52 restoring steps produce 27 fractional quotient bits plus exact remainder.
   // The remainder contributes sticky information through gradual-underflow packing.
   DIVIDE:begin
    dividend_r<=dividend_r<<1;
    quotient_r<={quotient_r[49:0],(div_trial>={1'b0,mb_r})};
    remainder_r<=24'(div_trial>={1'b0,mb_r}?div_trial-{1'b0,mb_r}:div_trial);
    div_count_r<=div_count_r-1'b1;
    if(div_count_r==1) begin
     mag_r<={236'b0,quotient_r[50:0],(div_trial>={1'b0,mb_r})};
     sticky_r<= (div_trial>={1'b0,mb_r}?div_trial-{1'b0,mb_r}:div_trial)!=0;
     state_r<=PACK;
    end
   end
   PACK:begin
    if((|mag_r[287:24]) || power_r < -11'sd149) begin
     mag_r<=mag_r>>1;sticky_r<=sticky_r|guard_r;guard_r<=mag_r[0];power_r<=power_r+1'b1;
    end else if(mag_r!=0 && !mag_r[23] && power_r > -11'sd149) begin
     mag_r<=mag_r<<1;power_r<=power_r-1'b1;
    end else state_r<=ROUND;
   end
   ROUND:begin
    if(rounded[24]) begin mag_r<={264'b0,rounded[24:1]};power_r<=power_r+1'b1;end
    else mag_r<={263'b0,rounded};
    state_r<=ENCODE;
   end
   ENCODE:begin
    if(mag_r==0) resp_data<={sign_r,31'b0};
    else if(power_r>11'sd104) begin resp_data<=0;resp_error<=1;end
    else if(!mag_r[23]) resp_data<={sign_r,8'b0,mag_r[22:0]};
    else resp_data<={sign_r,encoded_exp,mag_r[22:0]};
    state_r<=RESPONSE;
   end
   RESPONSE:if(resp_ready) state_r<=IDLE;
   default:state_r<=IDLE;
  endcase
 end
endmodule
