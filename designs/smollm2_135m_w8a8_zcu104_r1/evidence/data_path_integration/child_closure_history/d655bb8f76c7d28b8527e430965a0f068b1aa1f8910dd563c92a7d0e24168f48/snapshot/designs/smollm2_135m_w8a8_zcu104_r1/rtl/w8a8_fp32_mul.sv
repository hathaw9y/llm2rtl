// Exact IEEE binary32 finite multiplication, six elastic stages, II=1.
module w8a8_fp32_mul(
 input logic clk, resetn, s_valid, output logic s_ready,
 input logic [31:0] s_a,s_b, input logic [95:0] s_tag,
 output logic m_valid,input logic m_ready,output logic [31:0] m_result,
 output logic [95:0] m_tag,output logic m_nonfinite);
 logic [5:0] valid_r; logic ready_w[0:5];
 logic [95:0] tag_r[0:5]; logic sign_r[0:5],zero_r[0:5],special_r[0:5];
 logic [23:0] a_r,b_r; logic signed [10:0] exp_r[0:5];
 logic [47:0] prod_r,norm_r; logic [24:0] quotient_r,rounded_r;
 logic guard_r,sticky_r; logic [31:0] result_r;
 logic [23:0] a_w,b_w; logic signed [10:0] ea_w,eb_w;
 logic [47:0] normalized_w; logic signed [10:0] normalized_exp_w;
 logic [24:0] quotient_w; logic guard_w,sticky_w; integer shift_w,k;
 logic [24:0] rounded_w; logic signed [10:0] packed_exp_w;logic [31:0] packed_w;
 always_comb begin
   a_w={s_a[30:23]!=0,s_a[22:0]}; b_w={s_b[30:23]!=0,s_b[22:0]};
   ea_w=(s_a[30:23]==0)?-11'sd126:11'({1'b0,s_a[30:23]})-11'sd127;
   eb_w=(s_b[30:23]==0)?-11'sd126:11'({1'b0,s_b[30:23]})-11'sd127;
   begin : normalize_inputs
     integer pa,pb;
     pa=23;pb=23;
     for(integer j=0;j<24;j=j+1) begin
       if(a_w[j]) pa=j;
       if(b_w[j]) pb=j;
     end
     a_w=a_w<<(23-pa); b_w=b_w<<(23-pb);
     ea_w=ea_w-11'(23-pa);eb_w=eb_w-11'(23-pb);
   end
 end
 always_comb begin
   normalized_w=prod_r[47]?prod_r:(prod_r<<1);
   normalized_exp_w=exp_r[1]+(prod_r[47]?11'sd1:11'sd0);
   shift_w=(exp_r[2]<-11'sd126)?24+(-126-integer'(exp_r[2])):24;
   quotient_w=0;guard_w=0;sticky_w=0;
   if(shift_w<=48) begin
     quotient_w=25'(norm_r >> shift_w);
     guard_w=norm_r[shift_w-1];
   end
   for(k=0;k<48;k=k+1) if(k<shift_w-1) sticky_w=sticky_w|norm_r[k];
   rounded_w=quotient_r+{24'd0,(guard_r & (sticky_r|quotient_r[0]))};
   packed_exp_w=exp_r[4];
   if(rounded_r[24]) packed_exp_w=packed_exp_w+11'sd1;
   packed_w={sign_r[4],31'd0};
   if(special_r[4]) packed_w=32'h7fc00000;
   else if(!zero_r[4]) begin
     if(packed_exp_w>11'sd127) packed_w={sign_r[4],8'hff,23'd0};
     else if(exp_r[4]<-11'sd126) packed_w={sign_r[4],7'd0,rounded_r[23:0]};
     else packed_w={sign_r[4],8'(packed_exp_w+11'sd127),rounded_r[24]?rounded_r[23:1]:rounded_r[22:0]};
   end
 end
 assign ready_w[5]=!valid_r[5]||m_ready;
 for(genvar j=0;j<5;j=j+1) begin: ready_chain
   assign ready_w[j]=m_ready || !( &valid_r[5:j]);
 end
 assign s_ready=ready_w[0] & resetn; assign m_valid=valid_r[5];
 assign m_result=result_r;assign m_tag=tag_r[5];assign m_nonfinite=result_r[30:23]==8'hff;
 always_ff @(posedge clk) begin
   if(!resetn) begin valid_r<=0;result_r<=0;end
   else begin
     for(integer j=0;j<6;j=j+1) if(ready_w[j]) begin
       valid_r[j]<=(j==0)?s_valid:valid_r[j-1];
       if(j==0) begin tag_r[j]<=s_tag;sign_r[j]<=s_a[31]^s_b[31];zero_r[j]<=s_a[30:0]==0||s_b[30:0]==0;special_r[j]<=s_a[30:23]==255||s_b[30:23]==255;exp_r[j]<=ea_w+eb_w;end
       else begin tag_r[j]<=tag_r[j-1];sign_r[j]<=sign_r[j-1];zero_r[j]<=zero_r[j-1];special_r[j]<=special_r[j-1];exp_r[j]<=exp_r[j-1];end
     end
     if(ready_w[0]) begin a_r<=a_w;b_r<=b_w;end
     if(ready_w[1]) prod_r<=a_r*b_r;
     if(ready_w[2]) begin norm_r<=normalized_w;exp_r[2]<=normalized_exp_w;end
     if(ready_w[3]) begin quotient_r<=quotient_w;guard_r<=guard_w;sticky_r<=sticky_w;end
     if(ready_w[4]) rounded_r<=rounded_w;
     if(ready_w[5]) result_r<=packed_w;
   end
 end
endmodule
