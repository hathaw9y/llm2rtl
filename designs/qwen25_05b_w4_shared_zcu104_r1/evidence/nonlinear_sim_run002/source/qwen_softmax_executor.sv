module qwen_softmax_executor(
  input logic clk,rst_n,input logic cmd_valid,output logic cmd_ready,
  input logic [9:0] cmd_id,input logic [4:0] cmd_src,cmd_dst,cmd_rows,
  input logic [10:0] cmd_length,cmd_position,
  output logic rsp_valid,input logic rsp_ready,output logic [9:0] rsp_cmd_id,
  output logic rsp_error,output logic [7:0] rsp_error_code,
  output logic src_rd_en,output logic [12:0] src_rd_addr,input logic [127:0] src_rd_data,
  output logic dst_wr_en,output logic [12:0] dst_wr_addr,output logic [127:0] dst_wr_data,output logic [15:0] dst_wr_mask
);
  import qwen_fp32_pkg::*;
  typedef enum logic [3:0] {IDLE,CLEAR_DST,READ_SCORE,WAIT_SCORE,ISSUE_FP,WAIT_FP,
    ISSUE_EXP,WAIT_EXP,ISSUE_REDUCE,WAIT_REDUCE,ISSUE_RECIP,WAIT_RECIP,PACK,WRITE_WORD,RESPONSE} state_t;
  state_t state_r;
  logic [9:0] id_r;
  logic [4:0] rows_r,row_r;
  logic [10:0] length_r,position_r,col_r;
  logic [12:0] clear_r,clear_words_r;
  logic [1:0] pass_r,latency_r,stage_r;
  logic [31:0] x_r,scaled_r,maximum_r,sum_r,red_r,exp_r,reciprocal_r,shifted_r;
  logic [31:0] values_r[0:15];logic [511:0] values_flat;
  logic [127:0] packed_r;logic [15:0] output_r;
  logic error_r;logic [7:0] error_code_r;
  logic allowed;
  logic fp_valid,fp_ready,fp_rsp_valid,fp_rsp_ready,fp_error,fp_multiply;
  logic [31:0] fp_a,fp_b,fp_data;logic [9:0] fp_id;
  logic red_valid,red_ready,red_rsp_valid,red_rsp_ready,red_error;
  logic [31:0] red_data;logic [9:0] red_id;
  logic nl_valid,nl_ready,nl_rsp_valid,nl_rsp_ready,nl_error;
  logic [31:0] nl_x,nl_data;logic [9:0] nl_id;logic [1:0] nl_mode;
  logic [31:0] score_word;logic [15:0] score_bf,fp_bf;
  for(genvar i=0;i<16;i=i+1) assign values_flat[i*32+:32]=values_r[i];
  function automatic logic greater(input logic [31:0] a,b);
    if(a[30:0]==0 && b[30:0]==0) return 0;
    if(a[31]!=b[31]) return !a[31];
    return a[31]?a[30:0]<b[30:0]:a[30:0]>b[30:0];
  endfunction
  assign cmd_ready=state_r==IDLE && rst_n;assign rsp_valid=state_r==RESPONSE;
  assign rsp_cmd_id=id_r;assign rsp_error=error_r;assign rsp_error_code=error_code_r;
  assign allowed={1'b0,col_r}<={1'b0,position_r}+12'(row_r);
  assign src_rd_en=state_r==READ_SCORE;assign src_rd_addr=13'(int'(row_r)*256+int'(col_r)/4);
  assign score_word=src_rd_data[col_r[1:0]*32+:32];assign score_bf=to_bf16(score_word);assign fp_bf=to_bf16(fp_data);
  assign dst_wr_en=state_r==CLEAR_DST || state_r==WRITE_WORD;
  assign dst_wr_addr=state_r==CLEAR_DST?clear_r:13'(int'(row_r)*128+int'(col_r)/8);
  assign dst_wr_data=state_r==CLEAR_DST?128'b0:packed_r;assign dst_wr_mask=16'hffff;
  assign fp_valid=state_r==ISSUE_FP;assign fp_rsp_ready=state_r==WAIT_FP;
  assign red_valid=state_r==ISSUE_REDUCE;assign red_rsp_ready=state_r==WAIT_REDUCE;
  assign nl_valid=state_r==ISSUE_EXP || state_r==ISSUE_RECIP;
  assign nl_rsp_ready=state_r==WAIT_EXP || state_r==WAIT_RECIP;
  assign nl_mode=state_r==ISSUE_RECIP?2'd1:2'd0;assign nl_x=state_r==ISSUE_RECIP?sum_r:shifted_r;
  qwen_fp32_pipe arithmetic(.clk,.rst_n,.cmd_valid(fp_valid),.cmd_ready(fp_ready),.cmd_id(id_r),
    .cmd_multiply(fp_multiply),.cmd_a(fp_a),.cmd_b(fp_b),.rsp_valid(fp_rsp_valid),.rsp_ready(fp_rsp_ready),.rsp_id(fp_id),.rsp_data(fp_data),.rsp_error(fp_error));
  qwen_reduce16_scalar reduce16(.clk,.rst_n,.cmd_valid(red_valid),.cmd_ready(red_ready),.cmd_id(id_r),.cmd_values(values_flat),
    .rsp_valid(red_rsp_valid),.rsp_ready(red_rsp_ready),.rsp_cmd_id(red_id),.rsp_data(red_data),.rsp_error(red_error));
  qwen_nonlinear_scalar nonlinear(.clk,.rst_n,.cmd_valid(nl_valid),.cmd_ready(nl_ready),.cmd_id(id_r),.cmd_mode(nl_mode),.cmd_x(nl_x),
    .rsp_valid(nl_rsp_valid),.rsp_ready(nl_rsp_ready),.rsp_cmd_id(nl_id),.rsp_data(nl_data),.rsp_error(nl_error));
  always_comb begin
    fp_a=x_r;fp_b=32'h3e000000;fp_multiply=1;
    case(stage_r)
      1:begin fp_a=scaled_r;fp_b=maximum_r^32'h80000000;fp_multiply=0;end
      2:begin fp_a=sum_r;fp_b=red_r;fp_multiply=0;end
      3:begin fp_a=exp_r;fp_b=reciprocal_r;fp_multiply=1;end
      default:begin fp_a=x_r;fp_b=32'h3e000000;fp_multiply=1;end
    endcase
  end
  task automatic fault(input logic [7:0] code);
    error_r<=1;error_code_r<=code;state_r<=RESPONSE;
  endtask
  task automatic next_column;
    if(col_r==length_r-1'b1) begin col_r<=0;pass_r<=pass_r+1'b1;state_r<=READ_SCORE;end
    else begin col_r<=col_r+1'b1;state_r<=READ_SCORE;end
  endtask
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      state_r<=IDLE;id_r<=0;rows_r<=0;row_r<=0;length_r<=0;position_r<=0;col_r<=0;clear_r<=0;clear_words_r<=0;
      pass_r<=0;latency_r<=0;stage_r<=0;x_r<=0;scaled_r<=0;maximum_r<=0;sum_r<=0;red_r<=0;exp_r<=0;reciprocal_r<=0;shifted_r<=0;
      packed_r<=0;output_r<=0;error_r<=0;error_code_r<=0;for(integer i=0;i<16;i=i+1) values_r[i]<=0;
    end else case(state_r)
      IDLE:if(cmd_valid && cmd_ready) begin
        id_r<=cmd_id;rows_r<=cmd_rows;row_r<=0;length_r<=cmd_length;position_r<=cmd_position;col_r<=0;clear_r<=0;clear_words_r<=13'(int'(cmd_rows)*128);
        pass_r<=0;maximum_r<=0;sum_r<=0;packed_r<=0;error_r<=0;error_code_r<=0;state_r<=CLEAR_DST;
        for(integer i=0;i<16;i=i+1) values_r[i]<=0;
        if(cmd_rows==0 || cmd_rows>16 || cmd_length==0 || cmd_length>1024 || int'(cmd_position)+int'(cmd_rows)!=int'(cmd_length)) fault(8'h01);
        else if(cmd_src!=18 || cmd_dst!=21) fault(8'h02);
      end
      CLEAR_DST:if(clear_r==clear_words_r-1'b1) state_r<=READ_SCORE;else clear_r<=clear_r+1'b1;
      READ_SCORE:begin latency_r<=3;state_r<=WAIT_SCORE;end
      WAIT_SCORE:if(latency_r==1) begin
        x_r<=from_bf16(score_bf);stage_r<=0;state_r<=ISSUE_FP;
        if(score_word[30:23]==255 || score_bf[14:7]==255) fault(8'h03);
      end else latency_r<=latency_r-1'b1;
      ISSUE_FP:if(fp_ready) state_r<=WAIT_FP;
      WAIT_FP:if(fp_rsp_valid) begin
        if(fp_error || fp_id!=id_r) fault(8'h04);
        else case(stage_r)
          0:begin
            scaled_r<=from_bf16(fp_bf);
            if(pass_r==0) begin
              if(allowed && (col_r==0 || greater(from_bf16(fp_bf),maximum_r))) maximum_r<=from_bf16(fp_bf);
              next_column();
            end else if(allowed) begin stage_r<=1;state_r<=ISSUE_FP;end
            else if(pass_r==1) begin
              values_r[col_r[3:0]]<=0;
              if(col_r[3:0]==15 || col_r==length_r-1'b1) state_r<=ISSUE_REDUCE;
              else next_column();
            end else begin output_r<=0;state_r<=PACK;end
          end
          1:begin shifted_r<=fp_data;state_r<=ISSUE_EXP;end
          2:begin
            sum_r<=fp_data;for(integer i=0;i<16;i=i+1) values_r[i]<=0;
            if(col_r==length_r-1'b1) state_r<=ISSUE_RECIP;
            else begin col_r<=col_r+1'b1;state_r<=READ_SCORE;end
          end
          3:begin output_r<=fp_bf;state_r<=PACK;end
          default:fault(8'hff);
        endcase
      end
      ISSUE_EXP:if(nl_ready) state_r<=WAIT_EXP;
      WAIT_EXP:if(nl_rsp_valid) begin
        if(nl_error || nl_id!=id_r) fault(8'h04);
        else if(pass_r==1) begin
          values_r[col_r[3:0]]<=nl_data;
          if(col_r[3:0]==15 || col_r==length_r-1'b1) state_r<=ISSUE_REDUCE;
          else next_column();
        end else begin exp_r<=nl_data;stage_r<=3;state_r<=ISSUE_FP;end
      end
      ISSUE_REDUCE:if(red_ready) state_r<=WAIT_REDUCE;
      WAIT_REDUCE:if(red_rsp_valid) begin
        red_r<=red_data;stage_r<=2;state_r<=ISSUE_FP;
        if(red_error || red_id!=id_r) fault(8'h04);
      end
      ISSUE_RECIP:if(nl_ready) state_r<=WAIT_RECIP;
      WAIT_RECIP:if(nl_rsp_valid) begin
        reciprocal_r<=nl_data;pass_r<=2;col_r<=0;packed_r<=0;state_r<=READ_SCORE;
        if(nl_error || nl_id!=id_r) fault(8'h04);
      end
      PACK:begin
        packed_r[col_r[2:0]*16+:16]<=output_r;
        if(col_r[2:0]==7 || col_r==length_r-1'b1) state_r<=WRITE_WORD;
        else begin col_r<=col_r+1'b1;state_r<=READ_SCORE;end
      end
      WRITE_WORD:begin
        packed_r<=0;
        if(col_r==length_r-1'b1) begin
          if(row_r==rows_r-1'b1) state_r<=RESPONSE;
          else begin row_r<=row_r+1'b1;col_r<=0;pass_r<=0;maximum_r<=0;sum_r<=0;state_r<=READ_SCORE;end
        end else begin col_r<=col_r+1'b1;state_r<=READ_SCORE;end
      end
      RESPONSE:if(rsp_ready) state_r<=IDLE;
      default:fault(8'hff);
    endcase
  end
endmodule
