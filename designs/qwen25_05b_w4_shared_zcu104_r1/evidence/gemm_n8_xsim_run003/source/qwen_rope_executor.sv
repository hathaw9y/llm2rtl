module qwen_rope_executor(
  input logic clk,rst_n,
  input logic cmd_valid,output logic cmd_ready,
  input logic [9:0] cmd_id,
  input logic [4:0] cmd_src,cmd_param,cmd_dst,
  input logic [4:0] cmd_rows,
  input logic [3:0] cmd_heads,
  output logic rsp_valid,input logic rsp_ready,
  output logic [9:0] rsp_cmd_id,
  output logic rsp_error,output logic [7:0] rsp_error_code,
  output logic src_rd_en,output logic [12:0] src_rd_addr,input logic [127:0] src_rd_data,
  output logic param_rd_en,output logic [12:0] param_rd_addr,input logic [127:0] param_rd_data,
  output logic dst_wr_en,output logic [12:0] dst_wr_addr,
  output logic [127:0] dst_wr_data,output logic [15:0] dst_wr_mask
);
  import qwen_fp32_pkg::*;
  typedef enum logic [4:0] {IDLE,RD_X,WAIT_X,RD_ROT,WAIT_ROT,RD_COS,WAIT_COS,
    RD_SIN,WAIT_SIN,MUL0,WAIT_MUL0,MUL1,WAIT_MUL1,ADD0,WAIT_ADD0,WRITE_WORD,RESPONSE} state_t;
  state_t state_r;
  logic [9:0] id_r;
  logic [4:0] rows_r,row_r;
  logic [3:0] heads_r,head_r;
  logic [5:0] dim_r;
  logic [1:0] latency_r;
  logic [15:0] x_r,rot_r,cos_r,sin_r,p0_r,p1_r;
  logic [127:0] packed_r;
  logic error_r;logic [7:0] error_code_r;
  logic [12:0] x_word,rot_word;
  logic [5:0] rotated_dim;
  logic fp_cmd_valid,fp_cmd_ready,fp_multiply,fp_rsp_valid,fp_rsp_ready,fp_error;
  logic [31:0] fp_a,fp_b,fp_result;
  logic [9:0] fp_id;
  logic [15:0] converted;
  qwen_fp32_pipe arithmetic(.clk,.rst_n,.cmd_valid(fp_cmd_valid),.cmd_ready(fp_cmd_ready),
    .cmd_id(id_r),.cmd_multiply(fp_multiply),.cmd_a(fp_a),.cmd_b(fp_b),
    .rsp_valid(fp_rsp_valid),.rsp_ready(fp_rsp_ready),.rsp_id(fp_id),.rsp_data(fp_result),.rsp_error(fp_error));
  assign cmd_ready=state_r==IDLE && rst_n;
  assign rsp_valid=state_r==RESPONSE;assign rsp_cmd_id=id_r;
  assign rsp_error=error_r;assign rsp_error_code=error_code_r;
  assign rotated_dim=dim_r^6'd32;
  assign x_word=13'((int'(row_r)*int'(heads_r)*64+int'(head_r)*64+int'(dim_r))/8);
  assign rot_word=13'((int'(row_r)*int'(heads_r)*64+int'(head_r)*64+int'(rotated_dim))/8);
  assign src_rd_en=state_r==RD_X || state_r==RD_ROT;
  assign src_rd_addr=state_r==RD_ROT?rot_word:x_word;
  assign param_rd_en=state_r==RD_COS || state_r==RD_SIN;
  assign param_rd_addr=13'(int'(row_r)*16+int'(dim_r)/8+(state_r==RD_SIN?8:0));
  assign dst_wr_en=state_r==WRITE_WORD;
  assign dst_wr_addr=x_word;assign dst_wr_data=packed_r;assign dst_wr_mask=16'hffff;
  assign fp_cmd_valid=state_r==MUL0 || state_r==MUL1 || state_r==ADD0;
  assign fp_multiply=state_r!=ADD0;
  assign fp_a=from_bf16(state_r==MUL0?x_r:state_r==MUL1?rot_r:p0_r);
  assign fp_b=from_bf16(state_r==MUL0?cos_r:state_r==MUL1?sin_r:p1_r);
  assign fp_rsp_ready=state_r==WAIT_MUL0 || state_r==WAIT_MUL1 || state_r==WAIT_ADD0;
  assign converted=to_bf16(fp_result);
  task automatic fault(input logic [7:0] code);
    error_r<=1'b1;error_code_r<=code;state_r<=RESPONSE;
  endtask
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      state_r<=IDLE;id_r<=0;rows_r<=0;row_r<=0;heads_r<=0;head_r<=0;dim_r<=0;
      latency_r<=0;x_r<=0;rot_r<=0;cos_r<=0;sin_r<=0;p0_r<=0;p1_r<=0;
      packed_r<=0;error_r<=0;error_code_r<=0;
    end else begin
      case(state_r)
        IDLE: if(cmd_valid && cmd_ready) begin
          id_r<=cmd_id;rows_r<=cmd_rows;heads_r<=cmd_heads;
          row_r<=0;head_r<=0;dim_r<=0;packed_r<=0;error_r<=0;error_code_r<=0;
          if(cmd_rows==0 || cmd_rows>16 || (cmd_heads!=2 && cmd_heads!=14)) fault(8'h01);
          else if(cmd_src>=23 || cmd_param>=23 || cmd_dst>=23 || cmd_src==cmd_param || cmd_src==cmd_dst || cmd_param==cmd_dst) fault(8'h02);
          else state_r<=RD_X;
        end
        RD_X: begin latency_r<=3;state_r<=WAIT_X;end
        WAIT_X: if(latency_r==1) begin
          x_r<=src_rd_data[dim_r[2:0]*16+:16];state_r<=RD_ROT;
          if(src_rd_data[dim_r[2:0]*16+7+:8]==8'hff) fault(8'h03);
        end else latency_r<=latency_r-1'b1;
        RD_ROT: begin latency_r<=3;state_r<=WAIT_ROT;end
        WAIT_ROT: if(latency_r==1) begin
          rot_r<=src_rd_data[dim_r[2:0]*16+:16]^{!dim_r[5],15'b0};state_r<=RD_COS;
          if(src_rd_data[dim_r[2:0]*16+7+:8]==8'hff) fault(8'h03);
        end else latency_r<=latency_r-1'b1;
        RD_COS: begin latency_r<=3;state_r<=WAIT_COS;end
        WAIT_COS: if(latency_r==1) begin
          cos_r<=param_rd_data[dim_r[2:0]*16+:16];state_r<=RD_SIN;
          if(param_rd_data[dim_r[2:0]*16+7+:8]==8'hff) fault(8'h03);
        end else latency_r<=latency_r-1'b1;
        RD_SIN: begin latency_r<=3;state_r<=WAIT_SIN;end
        WAIT_SIN: if(latency_r==1) begin
          sin_r<=param_rd_data[dim_r[2:0]*16+:16];state_r<=MUL0;
          if(param_rd_data[dim_r[2:0]*16+7+:8]==8'hff) fault(8'h03);
        end else latency_r<=latency_r-1'b1;
        MUL0: if(fp_cmd_ready) state_r<=WAIT_MUL0;
        WAIT_MUL0: if(fp_rsp_valid) begin
          p0_r<=converted;state_r<=MUL1;
          if(fp_error || fp_id!=id_r || converted[14:7]==8'hff) fault(8'h04);
        end
        MUL1: if(fp_cmd_ready) state_r<=WAIT_MUL1;
        WAIT_MUL1: if(fp_rsp_valid) begin
          p1_r<=converted;state_r<=ADD0;
          if(fp_error || fp_id!=id_r || converted[14:7]==8'hff) fault(8'h04);
        end
        ADD0: if(fp_cmd_ready) state_r<=WAIT_ADD0;
        WAIT_ADD0: if(fp_rsp_valid) begin
          packed_r[dim_r[2:0]*16+:16]<=converted;
          if(fp_error || fp_id!=id_r || converted[14:7]==8'hff) fault(8'h04);
          else if(dim_r[2:0]==7) state_r<=WRITE_WORD;
          else begin dim_r<=dim_r+1'b1;state_r<=RD_X;end
        end
        WRITE_WORD: begin
          if(dim_r==63) begin
            dim_r<=0;
            if(head_r==heads_r-1'b1) begin
              head_r<=0;
              if(row_r==rows_r-1'b1) state_r<=RESPONSE;
              else begin row_r<=row_r+1'b1;state_r<=RD_X;end
            end else begin head_r<=head_r+1'b1;state_r<=RD_X;end
          end else begin dim_r<=dim_r+1'b1;state_r<=RD_X;end
        end
        RESPONSE: if(rsp_ready) state_r<=IDLE;
        default: fault(8'hff);
      endcase
    end
  end
endmodule
