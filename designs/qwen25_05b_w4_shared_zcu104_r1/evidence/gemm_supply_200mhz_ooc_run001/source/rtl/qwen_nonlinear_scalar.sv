module qwen_nonlinear_scalar #(
  parameter EXP_FILE="/tmp/qwen_gemm_supply_ooc_run001/source/exp2.mem",
  parameter RECIP_FILE="/tmp/qwen_gemm_supply_ooc_run001/source/reciprocal.mem",
  parameter RSQRT_FILE="/tmp/qwen_gemm_supply_ooc_run001/source/rsqrt.mem"
)(
  input logic clk,rst_n,
  input logic cmd_valid,output logic cmd_ready,
  input logic [9:0] cmd_id,
  input logic [1:0] cmd_mode, //0 exp(x<=0),1 reciprocal(x>0),2 rsqrt(x>0)
  input logic [31:0] cmd_x,
  output logic rsp_valid,input logic rsp_ready,
  output logic [9:0] rsp_cmd_id,
  output logic [31:0] rsp_data,
  output logic rsp_error
);
  logic [31:0] exp_rom[0:256],recip_rom[0:255],rsqrt_rom[0:255];
  initial begin $readmemh(EXP_FILE,exp_rom);$readmemh(RECIP_FILE,recip_rom);$readmemh(RSQRT_FILE,rsqrt_rom);end
  typedef enum logic [1:0] {IDLE,ISSUE,WAIT_FP,RESPONSE} state_t;
  state_t state_r;
  logic [9:0] id_r;
  logic [1:0] mode_r,iteration_r;
  logic [3:0] step_r;
  logic [31:0] x_r,norm_r,y_r,t0_r,t1_r,t2_r,z_r,result_r;
  logic [7:0] index_r;
  logic signed [9:0] exponent_r;
  logic error_r;
  logic fp_valid,fp_ready,fp_multiply,fp_rsp_valid,fp_rsp_ready,fp_error;
  logic [31:0] fp_a,fp_b,fp_result;
  logic [9:0] fp_id;
  function automatic logic [31:0] integer_fp(input logic signed [9:0] number);
    logic sign;logic [9:0] magnitude;logic [23:0] mantissa;logic [7:0] exponent;
    integer highest;
    sign=number<0;magnitude=sign?10'(-number):10'(number);highest=0;
    for(integer i=0;i<10;i=i+1) if(magnitude[i]) highest=i;
    if(magnitude==0) return 32'b0;
    mantissa=24'(magnitude)<<(23-highest);exponent=8'(127+highest);
    return {sign,exponent,mantissa[22:0]};
  endfunction
  function automatic logic signed [9:0] floor_fp(input logic [31:0] x);
    logic [23:0] mantissa;logic fraction;logic [9:0] magnitude;
    integer e,shift;
    mantissa={1'b1,x[22:0]};e=int'({1'b0,x[30:23]})-127;
    if(x[30:0]==0) return 10'sd0;
    if(e<0) return x[31]?-10'sd1:10'sd0;
    shift=23-e;magnitude=10'(mantissa>>shift);fraction=0;
    for(integer i=0;i<24;i=i+1) if(i<shift) fraction=fraction|mantissa[i];
    if(x[31]) return -$signed(magnitude)-10'(fraction);
    return $signed(magnitude);
  endfunction
  function automatic logic [31:0] scale_power(input logic [31:0] x,input logic signed [9:0] power);
    logic signed [10:0] e;
    e=$signed({3'b0,x[30:23]})+11'(power);
    if(x[30:23]==0) return {x[31],31'b0};
    if(e>=255) return {x[31],8'hff,23'b0};
    if(e<=0) begin
      if(e==0 && x[22:0]==23'h7fffff) return {x[31],8'd1,23'b0};
      return {x[31],31'b0};
    end
    return {x[31],e[7:0],x[22:0]};
  endfunction
  assign cmd_ready=state_r==IDLE && rst_n;
  assign rsp_valid=state_r==RESPONSE;assign rsp_data=result_r;
  assign rsp_cmd_id=id_r;assign rsp_error=error_r;
  assign fp_valid=state_r==ISSUE;
  assign fp_rsp_ready=state_r==WAIT_FP;
  qwen_fp32_pipe arithmetic(.clk,.rst_n,.cmd_valid(fp_valid),.cmd_ready(fp_ready),.cmd_id(id_r),
    .cmd_multiply(fp_multiply),.cmd_a(fp_a),.cmd_b(fp_b),.rsp_valid(fp_rsp_valid),
    .rsp_ready(fp_rsp_ready),.rsp_id(fp_id),.rsp_data(fp_result),.rsp_error(fp_error));
  always_comb begin
    fp_a=0;fp_b=0;fp_multiply=0;
    if(mode_r==0) begin
      case(step_r)
        0:begin fp_a=x_r;fp_b=32'h3fb8aa3b;fp_multiply=1;end
        1:begin fp_a=z_r;fp_b=integer_fp(-exponent_r);end
        2:begin fp_a=t0_r;fp_b=32'h43800000;fp_multiply=1;end
        3:begin fp_a=t0_r;fp_b=integer_fp(-$signed({2'b0,index_r}));end
        4:begin fp_a=exp_rom[{1'b0,index_r}+9'd1];fp_b=exp_rom[index_r]^32'h80000000;end
        5:begin fp_a=t1_r;fp_b=t2_r;fp_multiply=1;end
        6:begin fp_a=exp_rom[index_r];fp_b=t0_r;end
        default:begin fp_a=0;fp_b=0;end
      endcase
    end else if(mode_r==1) begin
      case(step_r)
        0:begin fp_a=norm_r;fp_b=y_r;fp_multiply=1;end
        1:begin fp_a=32'h40000000;fp_b=t0_r^32'h80000000;end
        2:begin fp_a=y_r;fp_b=t0_r;fp_multiply=1;end
        default:begin fp_a=0;fp_b=0;end
      endcase
    end else begin
      case(step_r)
        0:begin fp_a=32'h3f000000;fp_b=y_r;fp_multiply=1;end
        1:begin fp_a=norm_r;fp_b=y_r;fp_multiply=1;end
        2:begin fp_a=t1_r;fp_b=y_r;fp_multiply=1;end
        3:begin fp_a=32'h40400000;fp_b=t1_r^32'h80000000;end
        4:begin fp_a=t0_r;fp_b=t1_r;fp_multiply=1;end
        5:begin fp_a=y_r;fp_b=exponent_r[0]?32'h3f3504f3:32'h3f800000;fp_multiply=1;end
        default:begin fp_a=0;fp_b=0;end
      endcase
    end
  end
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      state_r<=IDLE;id_r<=0;mode_r<=0;iteration_r<=0;step_r<=0;
      x_r<=0;norm_r<=0;y_r<=0;t0_r<=0;t1_r<=0;t2_r<=0;z_r<=0;result_r<=0;
      index_r<=0;exponent_r<=0;error_r<=0;
    end else case(state_r)
      IDLE:if(cmd_valid && cmd_ready) begin
        id_r<=cmd_id;mode_r<=cmd_mode;x_r<=cmd_x;step_r<=0;iteration_r<=0;error_r<=0;
        norm_r<={1'b0,8'd127,cmd_x[22:0]};exponent_r<=$signed({2'b0,cmd_x[30:23]})-10'sd127;
        y_r<=cmd_mode==1?recip_rom[cmd_x[22:15]]:rsqrt_rom[cmd_x[22:15]];
        state_r<=ISSUE;
        if(cmd_mode>2 || cmd_x[30:23]==255 || (cmd_mode!=0 && (cmd_x[31] || cmd_x[30:23]==0)) || (cmd_mode==0 && !cmd_x[31] && cmd_x[30:0]!=0)) begin
          error_r<=1;result_r<=0;state_r<=RESPONSE;
        end else if(cmd_mode==0 && cmd_x[31] && cmd_x[30:0]>31'h42aeac50) begin
          result_r<=0;state_r<=RESPONSE;
        end
      end
      ISSUE:if(fp_ready) state_r<=WAIT_FP;
      WAIT_FP:if(fp_rsp_valid) begin
        state_r<=ISSUE;
        if(fp_error || fp_id!=id_r) begin error_r<=1;result_r<=0;state_r<=RESPONSE;end
        else if(mode_r==0) begin
          case(step_r)
            0:begin z_r<=fp_result;exponent_r<=floor_fp(fp_result);step_r<=1;end
            1:begin t0_r<=fp_result;step_r<=2;end
            2:begin t0_r<=fp_result;index_r<=floor_fp(fp_result)>=256?8'd255:8'(floor_fp(fp_result));step_r<=3;end
            3:begin t1_r<=fp_result;step_r<=4;end
            4:begin t2_r<=fp_result;step_r<=5;end
            5:begin t0_r<=fp_result;step_r<=6;end
            6:begin result_r<=scale_power(fp_result,exponent_r);state_r<=RESPONSE;end
            default:begin error_r<=1;state_r<=RESPONSE;end
          endcase
        end else if(mode_r==1) begin
          case(step_r)
            0:begin t0_r<=fp_result;step_r<=1;end
            1:begin t0_r<=fp_result;step_r<=2;end
            2:begin
              y_r<=fp_result;step_r<=0;iteration_r<=iteration_r+1'b1;
              if(iteration_r==1) begin result_r<=scale_power(fp_result,-exponent_r);state_r<=RESPONSE;end
            end
            default:begin error_r<=1;state_r<=RESPONSE;end
          endcase
        end else begin
          case(step_r)
            0:begin t0_r<=fp_result;step_r<=1;end
            1:begin t1_r<=fp_result;step_r<=2;end
            2:begin t1_r<=fp_result;step_r<=3;end
            3:begin t1_r<=fp_result;step_r<=4;end
            4:begin y_r<=fp_result;iteration_r<=iteration_r+1'b1;step_r<=iteration_r==2?5:0;end
            5:begin result_r<=scale_power(fp_result,-(exponent_r>>>1));state_r<=RESPONSE;end
            default:begin error_r<=1;state_r<=RESPONSE;end
          endcase
        end
      end
      RESPONSE:if(rsp_ready) state_r<=IDLE;
      default:state_r<=IDLE;
    endcase
  end
endmodule
