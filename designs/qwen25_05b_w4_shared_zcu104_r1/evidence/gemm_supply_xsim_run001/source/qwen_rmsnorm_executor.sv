module qwen_rmsnorm_executor(
  input logic clk,rst_n,
  input logic cmd_valid,output logic cmd_ready,
  input logic [9:0] cmd_id,
  input logic [4:0] cmd_src,cmd_param,cmd_dst,cmd_rows,
  input logic [10:0] cmd_cols,
  output logic rsp_valid,input logic rsp_ready,
  output logic [9:0] rsp_cmd_id,
  output logic rsp_error,output logic [7:0] rsp_error_code,
  output logic src_rd_en,output logic [12:0] src_rd_addr,input logic [127:0] src_rd_data,
  output logic param_rd_en,output logic [12:0] param_rd_addr,input logic [127:0] param_rd_data,
  output logic dst_wr_en,output logic [12:0] dst_wr_addr,
  output logic [127:0] dst_wr_data,output logic [15:0] dst_wr_mask
);
  import qwen_fp32_pkg::*;
  typedef enum logic [3:0] {IDLE,READ_X,WAIT_X,READ_GAMMA,WAIT_GAMMA,ISSUE_FP,WAIT_FP,
    ISSUE_REDUCE,WAIT_REDUCE,ISSUE_NL,WAIT_NL,WRITE_WORD,RESPONSE} state_t;
  state_t state_r;
  logic [9:0] id_r,element_r;
  logic [4:0] rows_r,row_r;
  logic [1:0] latency_r;
  logic [2:0] stage_r;
  logic pass2_r;
  logic [31:0] x_r,gamma_r,sum_r,red_r,mean_r,inverse_r,normalized_r;
  logic [31:0] squares_r[0:15];logic [511:0] squares_flat;
  logic [127:0] packed_r;
  logic error_r;logic [7:0] error_code_r;
  logic fp_valid,fp_ready,fp_rsp_valid,fp_rsp_ready,fp_error,fp_multiply;
  logic [31:0] fp_a,fp_b,fp_data;logic [9:0] fp_id;logic [15:0] fp_bf;
  logic red_valid,red_ready,red_rsp_valid,red_rsp_ready,red_error;
  logic [31:0] red_data;logic [9:0] red_id;
  logic nl_valid,nl_ready,nl_rsp_valid,nl_rsp_ready,nl_error;
  logic [31:0] nl_data;logic [9:0] nl_id;
  for(genvar i=0;i<16;i=i+1) assign squares_flat[i*32+:32]=squares_r[i];
  assign cmd_ready=state_r==IDLE && rst_n;assign rsp_valid=state_r==RESPONSE;
  assign rsp_cmd_id=id_r;assign rsp_error=error_r;assign rsp_error_code=error_code_r;
  assign src_rd_en=state_r==READ_X;assign src_rd_addr=13'(int'(row_r)*112+int'(element_r)/8);
  assign param_rd_en=state_r==READ_GAMMA;assign param_rd_addr=13'(int'(element_r)/8);
  assign dst_wr_en=state_r==WRITE_WORD;assign dst_wr_addr=src_rd_addr;
  assign dst_wr_data=packed_r;assign dst_wr_mask=16'hffff;
  assign fp_valid=state_r==ISSUE_FP;assign fp_rsp_ready=state_r==WAIT_FP;assign fp_bf=to_bf16(fp_data);
  assign red_valid=state_r==ISSUE_REDUCE;assign red_rsp_ready=state_r==WAIT_REDUCE;
  assign nl_valid=state_r==ISSUE_NL;assign nl_rsp_ready=state_r==WAIT_NL;
  qwen_fp32_pipe arithmetic(.clk,.rst_n,.cmd_valid(fp_valid),.cmd_ready(fp_ready),.cmd_id(id_r),
    .cmd_multiply(fp_multiply),.cmd_a(fp_a),.cmd_b(fp_b),.rsp_valid(fp_rsp_valid),.rsp_ready(fp_rsp_ready),.rsp_id(fp_id),.rsp_data(fp_data),.rsp_error(fp_error));
  qwen_reduce16_scalar reduce16(.clk,.rst_n,.cmd_valid(red_valid),.cmd_ready(red_ready),.cmd_id(id_r),.cmd_values(squares_flat),
    .rsp_valid(red_rsp_valid),.rsp_ready(red_rsp_ready),.rsp_cmd_id(red_id),.rsp_data(red_data),.rsp_error(red_error));
  qwen_nonlinear_scalar nonlinear(.clk,.rst_n,.cmd_valid(nl_valid),.cmd_ready(nl_ready),.cmd_id(id_r),.cmd_mode(2'd2),.cmd_x(mean_r),
    .rsp_valid(nl_rsp_valid),.rsp_ready(nl_rsp_ready),.rsp_cmd_id(nl_id),.rsp_data(nl_data),.rsp_error(nl_error));
  always_comb begin
    fp_multiply=1;fp_a=x_r;fp_b=x_r;
    case(stage_r)
      1:begin fp_multiply=0;fp_a=sum_r;fp_b=red_r;end
      2:begin fp_a=sum_r;fp_b=32'h3a924925;end
      3:begin fp_multiply=0;fp_a=mean_r;fp_b=32'h358637bd;end
      4:begin fp_a=x_r;fp_b=inverse_r;end
      5:begin fp_a=normalized_r;fp_b=gamma_r;end
      default:begin fp_a=x_r;fp_b=x_r;end
    endcase
  end
  task automatic fault(input logic [7:0] code);
    error_r<=1;error_code_r<=code;state_r<=RESPONSE;
  endtask
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      state_r<=IDLE;id_r<=0;element_r<=0;rows_r<=0;row_r<=0;latency_r<=0;stage_r<=0;pass2_r<=0;
      x_r<=0;gamma_r<=0;sum_r<=0;red_r<=0;mean_r<=0;inverse_r<=0;normalized_r<=0;packed_r<=0;error_r<=0;error_code_r<=0;
      for(integer i=0;i<16;i=i+1) squares_r[i]<=0;
    end else case(state_r)
      IDLE:if(cmd_valid && cmd_ready) begin
        id_r<=cmd_id;rows_r<=cmd_rows;row_r<=0;element_r<=0;sum_r<=0;pass2_r<=0;error_r<=0;error_code_r<=0;packed_r<=0;state_r<=READ_X;
        if(cmd_rows==0 || cmd_rows>16 || cmd_cols!=896) fault(8'h01);
        else if(cmd_src>3 || cmd_dst>3 || cmd_param!=22 || cmd_src==cmd_dst) fault(8'h02);
      end
      READ_X:begin latency_r<=3;state_r<=WAIT_X;end
      WAIT_X:if(latency_r==1) begin
        x_r<=from_bf16(src_rd_data[element_r[2:0]*16+:16]);stage_r<=0;state_r<=pass2_r?READ_GAMMA:ISSUE_FP;
        if(src_rd_data[element_r[2:0]*16+7+:8]==255) fault(8'h03);
      end else latency_r<=latency_r-1'b1;
      READ_GAMMA:begin latency_r<=3;state_r<=WAIT_GAMMA;end
      WAIT_GAMMA:if(latency_r==1) begin
        gamma_r<=from_bf16(param_rd_data[element_r[2:0]*16+:16]);stage_r<=4;state_r<=ISSUE_FP;
        if(param_rd_data[element_r[2:0]*16+7+:8]==255) fault(8'h03);
      end else latency_r<=latency_r-1'b1;
      ISSUE_FP:if(fp_ready) state_r<=WAIT_FP;
      WAIT_FP:if(fp_rsp_valid) begin
        if(fp_error || fp_id!=id_r) fault(8'h04);
        else case(stage_r)
          0:begin
            squares_r[element_r[3:0]]<=fp_data;
            if(element_r[3:0]==15) state_r<=ISSUE_REDUCE;
            else begin element_r<=element_r+1'b1;state_r<=READ_X;end
          end
          1:begin
            sum_r<=fp_data;
            if(element_r==895) begin stage_r<=2;state_r<=ISSUE_FP;end
            else begin element_r<=element_r+1'b1;state_r<=READ_X;end
          end
          2:begin mean_r<=fp_data;stage_r<=3;state_r<=ISSUE_FP;end
          3:begin mean_r<=fp_data;state_r<=ISSUE_NL;end
          4:begin normalized_r<=from_bf16(fp_bf);stage_r<=5;state_r<=ISSUE_FP;if(fp_bf[14:7]==255) fault(8'h04);end
          5:begin
            packed_r[element_r[2:0]*16+:16]<=fp_bf;
            if(fp_bf[14:7]==255) fault(8'h04);
            else if(element_r[2:0]==7) state_r<=WRITE_WORD;
            else begin element_r<=element_r+1'b1;state_r<=READ_X;end
          end
          default:fault(8'hff);
        endcase
      end
      ISSUE_REDUCE:if(red_ready) state_r<=WAIT_REDUCE;
      WAIT_REDUCE:if(red_rsp_valid) begin
        red_r<=red_data;stage_r<=1;state_r<=ISSUE_FP;
        if(red_error || red_id!=id_r) fault(8'h04);
      end
      ISSUE_NL:if(nl_ready) state_r<=WAIT_NL;
      WAIT_NL:if(nl_rsp_valid) begin
        inverse_r<=nl_data;pass2_r<=1;element_r<=0;state_r<=READ_X;
        if(nl_error || nl_id!=id_r) fault(8'h04);
      end
      WRITE_WORD:begin
        if(element_r==895) begin
          if(row_r==rows_r-1'b1) state_r<=RESPONSE;
          else begin row_r<=row_r+1'b1;element_r<=0;pass2_r<=0;sum_r<=0;state_r<=READ_X;end
        end else begin element_r<=element_r+1'b1;state_r<=READ_X;end
      end
      RESPONSE:if(rsp_ready) state_r<=IDLE;
      default:fault(8'hff);
    endcase
  end
endmodule
