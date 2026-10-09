module qwen_vector_executor(
  input logic clk,rst_n,
  input logic cmd_valid,output logic cmd_ready,
  input logic [9:0] cmd_id,
  input logic [4:0] cmd_src0,cmd_src1,cmd_dst,cmd_rows,cmd_dst_rows,
  input logic [10:0] cmd_cols,cmd_src_rows,
  input logic [12:0] cmd_src_cols,cmd_src1_cols,cmd_dst_cols,
  input logic [10:0] cmd_row,
  input logic [12:0] cmd_col,
  input logic [2:0] cmd_mode, // bias,add,silu_mul,dequant,cast,layout
  input logic cmd_insert,cmd_begin,
  output logic rsp_valid,input logic rsp_ready,
  output logic [9:0] rsp_cmd_id,
  output logic rsp_error,output logic [7:0] rsp_error_code,
  output logic src0_rd_en,output logic [12:0] src0_rd_addr,input logic [127:0] src0_rd_data,
  output logic src1_rd_en,output logic [12:0] src1_rd_addr,input logic [127:0] src1_rd_data,
  output logic dst_wr_en,output logic [12:0] dst_wr_addr,
  output logic [127:0] dst_wr_data,output logic [15:0] dst_wr_mask
);
  import qwen_fp32_pkg::*;
  typedef enum logic [4:0] {IDLE,CLEAR_DST,READ_A,WAIT_A,READ_B,WAIT_B,PREPARE,
    ISSUE_FP,WAIT_FP,ISSUE_NL,WAIT_NL,PACK,WRITE_WORD,RESPONSE} state_t;
  state_t state_r;
  logic [9:0] id_r;
  logic [4:0] rows_r,row_r;
  logic [10:0] cols_r,col_r;
  logic [12:0] source_stride_r,second_stride_r,dest_stride_r,clear_words_r,clear_r;
  logic [10:0] select_row_r;
  logic [12:0] select_col_r;
  logic [2:0] mode_r;
  logic insert_r;
  logic [1:0] latency_r;
  logic [3:0] stage_r;
  logic [31:0] x_r,y_r,e_r,sigmoid_r,tmp_r;
  logic [15:0] raw_bf_r,result_bf_r;
  logic [127:0] packed_r;
  logic error_r;logic [7:0] error_code_r;
  logic fp_valid,fp_ready,fp_rsp_valid,fp_rsp_ready,fp_multiply,fp_error;
  logic [31:0] fp_a,fp_b,fp_result;
  logic [9:0] fp_id;
  logic nl_valid,nl_ready,nl_rsp_valid,nl_rsp_ready,nl_error;
  logic [1:0] nl_mode;
  logic [31:0] nl_x,nl_result;
  logic [9:0] nl_id;
  logic [15:0] fp_bf,x_bf;
  logic [10:0] source_column;
  logic [3:0] source_bf_lane;
  logic [4:0] source_w4_lane;
  logic [2:0] second_bf_lane;
  logic [1:0] second_fp_lane;
  function automatic logic [31:0] w4_float(input logic [3:0] q);
    case(q)
      0:return 32'h00000000;1:return 32'h3f800000;2:return 32'h40000000;3:return 32'h40400000;
      4:return 32'h40800000;5:return 32'h40a00000;6:return 32'h40c00000;7:return 32'h40e00000;
      9:return 32'hc0e00000;10:return 32'hc0c00000;11:return 32'hc0a00000;12:return 32'hc0800000;
      13:return 32'hc0400000;14:return 32'hc0000000;15:return 32'hbf800000;
      default:return 32'h7fc00000;
    endcase
  endfunction
  function automatic integer bank_words(input logic [4:0] bank);
    case(bank)
      0,1,2,3,21:return 2048;
      4,5,6,19,20,22:return 256;
      7,11,12,13,14,15,16,17:return 512;
      8:return 64;
      9,10:return 8192;
      18:return 4096;
      default:return 0;
    endcase
  endfunction
  function automatic logic [12:0] first_stride(input logic [12:0] n,input logic [2:0] mode);
    logic [13:0] padded;
    case(mode)
      3:begin padded={1'b0,n}+14'd31;return 13'(padded>>5);end
      0,4:begin padded={1'b0,n}+14'd3;return 13'(padded>>2);end
      default:begin padded={1'b0,n}+14'd7;return 13'(padded>>3);end
    endcase
  endfunction
  function automatic logic [12:0] second_stride(input logic [12:0] n,input logic [2:0] mode);
    logic [13:0] padded;
    if(mode==3)begin padded={1'b0,n}+14'd3;return 13'(padded>>2);end
    padded={1'b0,n}+14'd7;return 13'(padded>>3);
  endfunction
  assign cmd_ready=state_r==IDLE && rst_n;
  assign rsp_valid=state_r==RESPONSE;assign rsp_cmd_id=id_r;assign rsp_error=error_r;assign rsp_error_code=error_code_r;
  assign source_column=col_r+((mode_r==5 && !insert_r)?11'(select_col_r):11'd0);
  assign source_bf_lane={1'b0,source_column[2:0]};assign source_w4_lane=source_column[4:0];
  assign second_bf_lane=col_r[2:0];assign second_fp_lane=col_r[8:7];
  assign src0_rd_en=state_r==READ_A;
  assign src0_rd_addr=13'((int'(row_r)+((mode_r==5 && !insert_r)?int'(select_row_r):0))*int'(source_stride_r)+
                          (mode_r==3?int'(source_column)/32:(mode_r==0 || mode_r==4)?int'(source_column)/4:int'(source_column)/8));
  assign src1_rd_en=state_r==READ_B;
  assign src1_rd_addr=13'((mode_r==0?0:int'(row_r))*int'(second_stride_r)+(mode_r==3?int'(col_r)/512:int'(col_r)/8));
  assign dst_wr_en=state_r==CLEAR_DST || state_r==WRITE_WORD;
  assign dst_wr_addr=state_r==CLEAR_DST?clear_r:13'((int'(row_r)+(insert_r?int'(select_row_r):0))*int'(dest_stride_r)+(int'(col_r)+(insert_r?int'(select_col_r):0))/8);
  assign dst_wr_data=state_r==CLEAR_DST?128'b0:packed_r;assign dst_wr_mask=16'hffff;
  assign fp_valid=state_r==ISSUE_FP;assign fp_rsp_ready=state_r==WAIT_FP;
  assign nl_valid=state_r==ISSUE_NL;assign nl_rsp_ready=state_r==WAIT_NL;
  assign nl_mode=stage_r==0?2'd0:2'd1;
  assign nl_x=stage_r==0?{1'b1,x_r[30:0]}:tmp_r;
  assign fp_bf=to_bf16(fp_result);
  assign x_bf=to_bf16(x_r);
  qwen_fp32_pipe arithmetic(.clk,.rst_n,.cmd_valid(fp_valid),.cmd_ready(fp_ready),.cmd_id(id_r),
    .cmd_multiply(fp_multiply),.cmd_a(fp_a),.cmd_b(fp_b),.rsp_valid(fp_rsp_valid),.rsp_ready(fp_rsp_ready),.rsp_id(fp_id),.rsp_data(fp_result),.rsp_error(fp_error));
  qwen_nonlinear_scalar nonlinear(.clk,.rst_n,.cmd_valid(nl_valid),.cmd_ready(nl_ready),.cmd_id(id_r),
    .cmd_mode(nl_mode),.cmd_x(nl_x),.rsp_valid(nl_rsp_valid),.rsp_ready(nl_rsp_ready),.rsp_cmd_id(nl_id),.rsp_data(nl_result),.rsp_error(nl_error));
  always_comb begin
    fp_multiply=mode_r==3 || mode_r==2;fp_a=x_r;fp_b=y_r;
    if(mode_r==2) case(stage_r)
      1:begin fp_multiply=0;fp_a=32'h3f800000;fp_b=e_r;end
      3:begin fp_a=e_r;fp_b=sigmoid_r;end
      4:begin fp_a=x_r;fp_b=sigmoid_r;end
      5:begin fp_a=tmp_r;fp_b=y_r;end
      default:begin fp_a=0;fp_b=0;end
    endcase
  end
  task automatic fault(input logic [7:0] code);
    error_r<=1;error_code_r<=code;state_r<=RESPONSE;
  endtask
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      state_r<=IDLE;id_r<=0;rows_r<=0;row_r<=0;cols_r<=0;col_r<=0;
      source_stride_r<=0;second_stride_r<=0;dest_stride_r<=0;clear_words_r<=0;clear_r<=0;
      select_row_r<=0;select_col_r<=0;mode_r<=0;insert_r<=0;latency_r<=0;stage_r<=0;
      x_r<=0;y_r<=0;e_r<=0;sigmoid_r<=0;tmp_r<=0;raw_bf_r<=0;result_bf_r<=0;packed_r<=0;error_r<=0;error_code_r<=0;
    end else case(state_r)
      IDLE:if(cmd_valid && cmd_ready) begin
        id_r<=cmd_id;rows_r<=cmd_rows;cols_r<=cmd_cols;row_r<=0;col_r<=0;
        select_row_r<=cmd_row;select_col_r<=cmd_col;mode_r<=cmd_mode;insert_r<=cmd_mode==5 && cmd_insert;
        source_stride_r<=13'(int'(first_stride(cmd_src_cols,cmd_mode)));
        second_stride_r<=13'(int'(second_stride(cmd_src1_cols,cmd_mode)));
        dest_stride_r<=13'((int'(cmd_dst_cols)+7)/8);clear_words_r<=13'(int'(cmd_dst_rows)*((int'(cmd_dst_cols)+7)/8));clear_r<=0;
        error_r<=0;error_code_r<=0;packed_r<=0;state_r<=cmd_begin?CLEAR_DST:READ_A;
        if(cmd_mode>5 || cmd_rows==0 || cmd_rows>16 || cmd_cols==0 || cmd_cols>1024 || cmd_cols[2:0]!=0 || cmd_dst_cols[2:0]!=0 || cmd_src_cols>1024 || cmd_dst_cols>1024) fault(8'h01);
        else if(cmd_src0>=23 || cmd_dst>=23 || cmd_src0==cmd_dst || (cmd_mode<4 && (cmd_src1>=23 || cmd_src1==cmd_src0 || cmd_src1==cmd_dst))) fault(8'h02);
        else if(cmd_dst_rows==0 || int'(cmd_dst_rows)*((int'(cmd_dst_cols)+7)/8)>bank_words(cmd_dst)) fault(8'h03);
        else if(cmd_src_rows==0 || cmd_src_rows>16 || cmd_src_cols==0 || int'(cmd_src_rows)*(int'(first_stride(cmd_src_cols,cmd_mode)))>bank_words(cmd_src0)) fault(8'h03);
        else if(cmd_mode<4 && (cmd_src1_cols==0 || (cmd_mode==0?1:int'(cmd_rows))*(int'(second_stride(cmd_src1_cols,cmd_mode)))>bank_words(cmd_src1))) fault(8'h03);
        else if(cmd_mode!=5 && (cmd_src_rows!=cmd_rows || cmd_src_cols!=cmd_cols || cmd_dst_rows!=cmd_rows || cmd_dst_cols!=cmd_cols)) fault(8'h03);
        else if(cmd_mode==5 && cmd_insert && (cmd_src_rows!=cmd_rows || cmd_src_cols!=cmd_cols)) fault(8'h03);
        else if(cmd_mode==5 && (cmd_col[2:0]!=0 || (cmd_insert?(int'(cmd_row)+int'(cmd_rows)>int'(cmd_dst_rows) || int'(cmd_col)+int'(cmd_cols)>int'(cmd_dst_cols)):(int'(cmd_row)+int'(cmd_rows)>int'(cmd_src_rows) || int'(cmd_col)+int'(cmd_cols)>int'(cmd_src_cols))))) fault(8'h03);
      end
      CLEAR_DST:if(clear_r==clear_words_r-1'b1) state_r<=READ_A;else clear_r<=clear_r+1'b1;
      READ_A:begin latency_r<=3;state_r<=WAIT_A;end
      WAIT_A:if(latency_r==1) begin
        if(mode_r==3) x_r<=w4_float(src0_rd_data[source_w4_lane*4+:4]);
        else if(mode_r==0 || mode_r==4) x_r<=src0_rd_data[source_column[1:0]*32+:32];
        else begin x_r<=from_bf16(src0_rd_data[source_bf_lane*16+:16]);raw_bf_r<=src0_rd_data[source_bf_lane*16+:16];end
        state_r<=mode_r<4?READ_B:PREPARE;
        if(mode_r==3 && src0_rd_data[source_w4_lane*4+:4]==8) fault(8'h04);
      end else latency_r<=latency_r-1'b1;
      READ_B:begin latency_r<=3;state_r<=WAIT_B;end
      WAIT_B:if(latency_r==1) begin
        y_r<=mode_r==3?src1_rd_data[second_fp_lane*32+:32]:from_bf16(src1_rd_data[second_bf_lane*16+:16]);state_r<=PREPARE;
      end else latency_r<=latency_r-1'b1;
      PREPARE:begin
        stage_r<=0;
        if(mode_r==5) begin result_bf_r<=raw_bf_r;state_r<=PACK;end
        else if(x_r[30:23]==255 || (mode_r<4 && y_r[30:23]==255) || (mode_r==3 && (y_r[31] || y_r[30:0]==0))) fault(8'h05);
        else if(mode_r==4) begin
          result_bf_r<=x_bf;state_r<=PACK;
          if(x_bf[14:7]==8'hff) fault(8'h05);
        end else state_r<=mode_r==2?ISSUE_NL:ISSUE_FP;
      end
      ISSUE_FP:if(fp_ready) state_r<=WAIT_FP;
      WAIT_FP:if(fp_rsp_valid) begin
        if(fp_error || fp_id!=id_r) fault(8'h06);
        else if(mode_r!=2) begin
          result_bf_r<=fp_bf;state_r<=PACK;
          if(fp_bf[14:7]==8'hff) fault(8'h06);
        end else case(stage_r)
          1:begin tmp_r<=fp_result;stage_r<=2;state_r<=ISSUE_NL;end
          3:begin sigmoid_r<=fp_result;stage_r<=4;state_r<=ISSUE_FP;end
          4:begin tmp_r<=from_bf16(fp_bf);stage_r<=5;state_r<=ISSUE_FP;if(fp_bf[14:7]==8'hff) fault(8'h06);end
          5:begin result_bf_r<=fp_bf;state_r<=PACK;if(fp_bf[14:7]==8'hff) fault(8'h06);end
          default:fault(8'hff);
        endcase
      end
      ISSUE_NL:if(nl_ready) state_r<=WAIT_NL;
      WAIT_NL:if(nl_rsp_valid) begin
        if(nl_error || nl_id!=id_r) fault(8'h06);
        else if(stage_r==0) begin e_r<=nl_result;stage_r<=1;state_r<=ISSUE_FP;end
        else begin sigmoid_r<=nl_result;stage_r<=x_r[31]?3:4;state_r<=ISSUE_FP;end
      end
      PACK:begin
        packed_r[col_r[2:0]*16+:16]<=result_bf_r;
        if(col_r[2:0]==7) state_r<=WRITE_WORD;
        else begin col_r<=col_r+1'b1;state_r<=READ_A;end
      end
      WRITE_WORD:begin
        if(col_r==cols_r-1'b1) begin
          col_r<=0;
          if(row_r==rows_r-1'b1) state_r<=RESPONSE;
          else begin row_r<=row_r+1'b1;state_r<=READ_A;end
        end else begin col_r<=col_r+1'b1;state_r<=READ_A;end
      end
      RESPONSE:if(rsp_ready) state_r<=IDLE;
      default:fault(8'hff);
    endcase
  end
endmodule
