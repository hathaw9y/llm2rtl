module attention_exp_neg(
 input logic aclk,aresetn,input logic cmd_valid,output logic cmd_ready,
 input logic [15:0] cmd_id,input logic [31:0] cmd_x,
 output logic resp_valid,input logic resp_ready,output logic [15:0] resp_id,
 output logic [31:0] resp_data,output logic resp_error
);
 typedef enum logic [1:0] {IDLE,ISSUE,WAIT_RESULT,RESPONSE} state_t;
 state_t state_r;
 logic [3:0] step_r;
 logic [31:0] x_r,z_r,fraction_r,alpha_r,delta_r;
 logic signed [9:0] exponent_r;
 logic [7:0] index_r;
 logic alu_valid,alu_ready,alu_resp_valid,alu_resp_ready,alu_error;
 logic [2:0] alu_op;
 logic [31:0] alu_a,alu_b,alu_data,rom_lo,rom_hi;
 logic [15:0] alu_id;
 logic signed [9:0] floor_result;
 logic signed [10:0] scaled_exp;
 function automatic logic signed [9:0] floor_value(input logic [31:0] x);
  logic [23:0] mantissa;logic [9:0] magnitude;logic fraction;
  integer e,shift;
  e=int'({1'b0,x[30:23]})-127;mantissa={1'b1,x[22:0]};
  if(x[30:0]==0) return 0;
  if(e<0) return x[31]?-10'sd1:10'sd0;
  shift=23-e;magnitude=10'(mantissa>>shift);fraction=0;
  for(integer i=0;i<24;i=i+1) if(i<shift) fraction=fraction|mantissa[i];
  return x[31]?-$signed(magnitude)-10'(fraction):$signed(magnitude);
 endfunction
 function automatic logic [31:0] integer_float(input logic signed [9:0] x);
  logic [9:0] magnitude;logic [22:0] mantissa;logic [7:0] exponent;integer highest;
  magnitude=x[9]?10'(-x):10'(x);highest=0;
  for(integer i=0;i<10;i=i+1) if(magnitude[i]) highest=i;
  if(magnitude==0) return 0;
  mantissa=23'(24'(magnitude)<<(23-highest));exponent=8'(127+highest);
  return {x[9],exponent,mantissa[22:0]};
 endfunction
 assign cmd_ready=aresetn && state_r==IDLE;
 assign resp_valid=state_r==RESPONSE;
 assign alu_valid=state_r==ISSUE;
 assign alu_resp_ready=state_r==WAIT_RESULT;
 assign floor_result=floor_value(alu_data);
 assign scaled_exp=$signed({3'b0,alu_data[30:23]})+11'(exponent_r);
 attention_fp32_exp_rom u_lo(.address({1'b0,index_r}),.data(rom_lo));
 attention_fp32_exp_rom u_hi(.address({1'b0,index_r}+9'd1),.data(rom_hi));
 attention_fp32_alu u_alu(.aclk,.aresetn,.cmd_valid(alu_valid),.cmd_ready(alu_ready),
  .cmd_id(resp_id),.cmd_op(alu_op),.cmd_a(alu_a),.cmd_b(alu_b),
  .resp_valid(alu_resp_valid),.resp_ready(alu_resp_ready),.resp_id(alu_id),.resp_data(alu_data),.resp_error(alu_error));
 always_comb begin
  alu_a=0;alu_b=0;alu_op=0;
  case(step_r)
   0:begin alu_a=x_r;alu_b=32'h3fb8aa3b;alu_op=1;end
   1:begin alu_a=z_r;alu_b=integer_float(-exponent_r);end
   2:begin alu_a=fraction_r;alu_b=32'h43800000;alu_op=1;end
   3:begin alu_a=alpha_r;alu_b=integer_float(-$signed({2'b0,index_r}));end
   4:begin alu_a=rom_hi;alu_b=rom_lo;alu_op=4;end
   5:begin alu_a=delta_r;alu_b=alpha_r;alu_op=1;end
   6:begin alu_a=rom_lo;alu_b=delta_r;end
   default:begin end
  endcase
 end
 always_ff @(posedge aclk) begin
  if(!aresetn) begin
   state_r<=IDLE;step_r<=0;x_r<=0;z_r<=0;fraction_r<=0;alpha_r<=0;delta_r<=0;
   exponent_r<=0;index_r<=0;resp_id<=0;resp_data<=0;resp_error<=0;
  end else case(state_r)
   IDLE:if(cmd_valid && cmd_ready) begin
    resp_id<=cmd_id;resp_error<=0;x_r<=cmd_x;step_r<=0;
    if(cmd_x[30:23]==255 || (!cmd_x[31] && cmd_x[30:0]!=0)) begin resp_error<=1;resp_data<=0;state_r<=RESPONSE;end
    else if(cmd_x[30:0]==0) begin resp_data<=32'h3f800000;state_r<=RESPONSE;end
    else if(cmd_x[30:0]>31'h42a00000) begin resp_data<=0;state_r<=RESPONSE;end
    else state_r<=ISSUE;
   end
   ISSUE:if(alu_ready) state_r<=WAIT_RESULT;
   WAIT_RESULT:if(alu_resp_valid) begin
    if(alu_error || alu_id!=resp_id) begin resp_error<=1;resp_data<=0;state_r<=RESPONSE;end
    else begin
     state_r<=ISSUE;step_r<=step_r+1'b1;
     case(step_r)
      0:begin z_r<=alu_data;exponent_r<=floor_result;end
      1:fraction_r<=alu_data;
      2:begin alpha_r<=alu_data;index_r<=floor_result>=256?8'd255:8'(floor_result);end
      3:alpha_r<=alu_data;
      4:delta_r<=alu_data;
      5:delta_r<=alu_data;
      6:begin
       if(scaled_exp<=0 || scaled_exp>=255) begin resp_error<=1;resp_data<=0;end
       else resp_data<={1'b0,scaled_exp[7:0],alu_data[22:0]};
       state_r<=RESPONSE;
      end
      default:begin resp_error<=1;state_r<=RESPONSE;end
     endcase
    end
   end
   RESPONSE:if(resp_ready) state_r<=IDLE;
   default:state_r<=IDLE;
  endcase
 end
endmodule
