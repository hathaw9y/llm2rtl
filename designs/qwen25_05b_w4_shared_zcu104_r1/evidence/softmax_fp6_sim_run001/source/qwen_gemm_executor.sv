module qwen_gemm_executor(
  input logic clk,rst_n,input logic cmd_valid,output logic cmd_ready,
  input logic [9:0] cmd_id,input logic [4:0] cmd_a,cmd_b,cmd_scale,cmd_dst,cmd_rows,
  input logic [10:0] cmd_n,cmd_k,input logic [1:0] cmd_mode,input logic cmd_init,
  output logic rsp_valid,input logic rsp_ready,output logic [9:0] rsp_cmd_id,
  output logic rsp_error,output logic [7:0] rsp_error_code,
  output logic act_rd_en,output logic [12:0] act_rd_addr,input logic [127:0] act_rd_data,
  output logic wgt_rd_en,output logic [12:0] wgt_rd_addr,input logic [127:0] wgt_rd_data,
  output logic scale_rd_en,output logic [12:0] scale_rd_addr,input logic [127:0] scale_rd_data,
  output logic dst_rd_en,output logic [12:0] dst_rd_addr,input logic [127:0] dst_rd_data,
  output logic dst_wr_en,output logic [12:0] dst_wr_addr,output logic [127:0] dst_wr_data,output logic [15:0] dst_wr_mask
);
  import qwen_fp32_pkg::*;
  typedef enum logic [4:0] {IDLE,CLEAR_DST,BEGIN_OUTPUT,READ_ACT,WAIT_ACT,READ_WGT,WAIT_WGT,
    ISSUE_DOT,WAIT_DOT,ISSUE_ALU,WAIT_ALU,READ_SCALE,WAIT_SCALE,READ_PREVIOUS,WAIT_PREVIOUS,WRITE_WORD,RESPONSE} state_t;
  state_t state_r;
  logic [9:0] id_r;
  logic [4:0] rows_r,row_r;
  logic [10:0] n_r,k_r,col_r,k_start_r;
  logic [1:0] mode_r,latency_r,output_lane_r,alu_stage_r;
  logic initialize_r,subword_r;
  logic [4:0] key_lane_r;
  logic [12:0] act_stride_r,dst_stride_r,clear_r,clear_words_r;
  logic [31:0] av_r[0:15],bv_r[0:3][0:15];
  logic [31:0] accumulator_r[0:3],tree_r[0:3],scales_r[0:3],contribution_r[0:3],previous_r[0:3],result_r[0:3];
  logic [511:0] av_flat;logic [2047:0] bv_flat;
  logic dot_valid,dot_ready,dot_rsp_valid,dot_rsp_ready,dot_error;
  logic [9:0] dot_id;logic [127:0] dot_data;
  logic [3:0] alu_valid,alu_ready,alu_rsp_valid,alu_rsp_ready,alu_error;
  logic [31:0] alu_a[0:3],alu_b[0:3],alu_data[0:3];logic [9:0] alu_id[0:3];
  logic alu_multiply,all_alu_ready,all_alu_valid;
  logic error_r;logic [7:0] error_code_r;
  logic [127:0] output_word;
  function automatic logic [31:0] code_float(input logic [3:0] q);
    case(q)
      0:return 32'h00000000;1:return 32'h3f800000;2:return 32'h40000000;3:return 32'h40400000;
      4:return 32'h40800000;5:return 32'h40a00000;6:return 32'h40c00000;7:return 32'h40e00000;
      9:return 32'hc0e00000;10:return 32'hc0c00000;11:return 32'hc0a00000;12:return 32'hc0800000;
      13:return 32'hc0400000;14:return 32'hc0000000;15:return 32'hbf800000;
      default:return 32'h7fc00000;
    endcase
  endfunction
  for(genvar j=0;j<16;j=j+1) assign av_flat[j*32+:32]=av_r[j];
  for(genvar o=0;o<4;o=o+1) begin
    for(genvar j=0;j<16;j=j+1) assign bv_flat[(o*16+j)*32+:32]=bv_r[o][j];
    assign output_word[o*32+:32]=col_r+11'(o)<n_r?result_r[o]:32'b0;
    assign alu_valid[o]=state_r==ISSUE_ALU;
    assign alu_rsp_ready[o]=state_r==WAIT_ALU;
    qwen_fp32_pipe scalar(.clk,.rst_n,.cmd_valid(alu_valid[o]),.cmd_ready(alu_ready[o]),.cmd_id(id_r),
      .cmd_multiply(alu_multiply),.cmd_a(alu_a[o]),.cmd_b(alu_b[o]),
      .rsp_valid(alu_rsp_valid[o]),.rsp_ready(alu_rsp_ready[o]),.rsp_id(alu_id[o]),.rsp_data(alu_data[o]),.rsp_error(alu_error[o]));
  end
  qwen_dot16x4 dot(.clk,.rst_n,.cmd_valid(dot_valid),.cmd_ready(dot_ready),.cmd_id(id_r),.cmd_a(av_flat),.cmd_b(bv_flat),
    .rsp_valid(dot_rsp_valid),.rsp_ready(dot_rsp_ready),.rsp_cmd_id(dot_id),.rsp_data(dot_data),.rsp_error(dot_error));
  assign cmd_ready=state_r==IDLE && rst_n;assign rsp_valid=state_r==RESPONSE;
  assign rsp_cmd_id=id_r;assign rsp_error=error_r;assign rsp_error_code=error_code_r;
  assign dot_valid=state_r==ISSUE_DOT;assign dot_rsp_ready=state_r==WAIT_DOT;
  assign all_alu_ready=&alu_ready;assign all_alu_valid=&alu_rsp_valid;
  assign alu_multiply=alu_stage_r==1;
  always_comb begin
    for(integer o=0;o<4;o=o+1) begin
      case(alu_stage_r)
        1:begin alu_a[o]=accumulator_r[o];alu_b[o]=scales_r[o];end
        2:begin alu_a[o]=previous_r[o];alu_b[o]=contribution_r[o];end
        default:begin alu_a[o]=accumulator_r[o];alu_b[o]=tree_r[o];end
      endcase
    end
  end
  assign act_rd_en=state_r==READ_ACT && k_start_r+(subword_r?11'd8:11'd0)<k_r;
  assign act_rd_addr=13'(int'(row_r)*int'(act_stride_r)+int'(k_start_r)/8+(subword_r?1:0));
  assign wgt_rd_en=state_r==READ_WGT && (mode_r==2?k_start_r+11'(key_lane_r)<k_r:col_r+11'(output_lane_r)<n_r);
  assign wgt_rd_addr=mode_r==0?13'((int'(col_r)+int'(output_lane_r))*4+int'(k_start_r)/32):
                     mode_r==1?13'((int'(col_r)+int'(output_lane_r))*8+int'(k_start_r)/8+(subword_r?1:0)):
                     13'((int'(k_start_r)+int'(key_lane_r))*8+int'(col_r)/8);
  assign scale_rd_en=state_r==READ_SCALE;assign scale_rd_addr=13'(int'(col_r)/4);
  assign dst_rd_en=state_r==READ_PREVIOUS;assign dst_rd_addr=13'(int'(row_r)*int'(dst_stride_r)+int'(col_r)/4);
  assign dst_wr_en=state_r==CLEAR_DST || state_r==WRITE_WORD;
  assign dst_wr_addr=state_r==CLEAR_DST?clear_r:dst_rd_addr;assign dst_wr_data=state_r==CLEAR_DST?128'b0:output_word;
  assign dst_wr_mask=16'hffff;
  task automatic fault(input logic [7:0] code);
    error_r<=1;error_code_r<=code;state_r<=RESPONSE;
  endtask
  task automatic next_weight;
    if(mode_r==2) begin
      if(key_lane_r==15) state_r<=ISSUE_DOT;
      else begin key_lane_r<=key_lane_r+1'b1;state_r<=READ_WGT;end
    end else if(mode_r==1 && !subword_r) begin subword_r<=1;state_r<=READ_WGT;end
    else if(output_lane_r==3) state_r<=ISSUE_DOT;
    else begin output_lane_r<=output_lane_r+1'b1;subword_r<=0;state_r<=READ_WGT;end
  endtask
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      state_r<=IDLE;id_r<=0;rows_r<=0;row_r<=0;n_r<=0;k_r<=0;col_r<=0;k_start_r<=0;mode_r<=0;
      latency_r<=0;output_lane_r<=0;alu_stage_r<=0;initialize_r<=0;subword_r<=0;key_lane_r<=0;
      act_stride_r<=0;dst_stride_r<=0;clear_r<=0;clear_words_r<=0;error_r<=0;error_code_r<=0;
      for(integer j=0;j<16;j=j+1) begin av_r[j]<=0;for(integer o=0;o<4;o=o+1) bv_r[o][j]<=0;end
      for(integer o=0;o<4;o=o+1) begin accumulator_r[o]<=0;tree_r[o]<=0;scales_r[o]<=0;contribution_r[o]<=0;previous_r[o]<=0;result_r[o]<=0;end
    end else case(state_r)
      IDLE:if(cmd_valid && cmd_ready) begin
        id_r<=cmd_id;rows_r<=cmd_rows;row_r<=0;n_r<=cmd_n;k_r<=cmd_k;col_r<=0;mode_r<=cmd_mode;initialize_r<=cmd_init;error_r<=0;error_code_r<=0;clear_r<=0;
        act_stride_r<=cmd_mode==0?13'd16:cmd_mode==1?13'd8:13'd128;
        dst_stride_r<=cmd_mode==1?13'd256:13'((int'(cmd_n)+3)/4);
        clear_words_r<=13'(int'(cmd_rows)*(cmd_mode==1?256:(int'(cmd_n)+3)/4));
        state_r<=cmd_init?CLEAR_DST:BEGIN_OUTPUT;
        if(cmd_rows==0 || cmd_rows>16 || cmd_mode>2 || cmd_n==0 || cmd_n>1024 || cmd_k==0 || cmd_k>1024) fault(8'h01);
        else if(cmd_mode==0 && (cmd_a!=6 || cmd_b!=7 || cmd_scale!=8 || cmd_n!=128 || cmd_k!=128 || !((cmd_dst>=11 && cmd_dst<=17) || cmd_dst==18))) fault(8'h02);
        else if(cmd_mode==1 && (cmd_a!=6 || cmd_b!=9 || cmd_dst!=18 || cmd_k!=64 || !cmd_init)) fault(8'h02);
        else if(cmd_mode==2 && (cmd_a!=21 || cmd_b!=10 || cmd_dst<11 || cmd_dst>17 || cmd_n!=64 || !cmd_init)) fault(8'h02);
      end
      CLEAR_DST:if(clear_r==clear_words_r-1'b1) state_r<=BEGIN_OUTPUT;else clear_r<=clear_r+1'b1;
      BEGIN_OUTPUT:begin
        k_start_r<=0;subword_r<=0;output_lane_r<=0;key_lane_r<=0;
        for(integer j=0;j<16;j=j+1) begin av_r[j]<=0;for(integer o=0;o<4;o=o+1) bv_r[o][j]<=0;end
        for(integer o=0;o<4;o=o+1) accumulator_r[o]<=0;
        state_r<=READ_ACT;
      end
      READ_ACT:begin
        if(k_start_r+(subword_r?11'd8:11'd0)>=k_r) begin
          for(integer j=0;j<8;j=j+1) av_r[(subword_r?8:0)+j]<=0;
          output_lane_r<=0;key_lane_r<=0;subword_r<=0;state_r<=READ_WGT;
        end else begin latency_r<=3;state_r<=WAIT_ACT;end
      end
      WAIT_ACT:if(latency_r==1) begin
        if(!subword_r) begin subword_r<=1;state_r<=READ_ACT;end
        else begin subword_r<=0;output_lane_r<=0;key_lane_r<=0;state_r<=READ_WGT;end
        for(integer j=0;j<8;j=j+1) begin
          av_r[(subword_r?8:0)+j]<=k_start_r+11'((subword_r?8:0)+j)<k_r?from_bf16(act_rd_data[j*16+:16]):32'b0;
          if(k_start_r+11'((subword_r?8:0)+j)<k_r && act_rd_data[j*16+7+:8]==255) fault(8'h03);
        end
      end else latency_r<=latency_r-1'b1;
      READ_WGT:begin
        if(mode_r==2 && k_start_r+11'(key_lane_r)>=k_r) begin
          for(integer o=0;o<4;o=o+1) bv_r[o][key_lane_r]<=0;
          next_weight();
        end else if(mode_r!=2 && col_r+11'(output_lane_r)>=n_r) begin
          for(integer j=0;j<16;j=j+1) bv_r[output_lane_r][j]<=0;
          if(output_lane_r==3) state_r<=ISSUE_DOT;
          else begin output_lane_r<=output_lane_r+1'b1;subword_r<=0;end
        end else begin latency_r<=3;state_r<=WAIT_WGT;end
      end
      WAIT_WGT:if(latency_r==1) begin
        next_weight();
        if(mode_r==0) for(integer j=0;j<16;j=j+1) begin
          bv_r[output_lane_r][j]<=code_float(wgt_rd_data[((k_start_r[4]?16:0)+j)*4+:4]);
          if(wgt_rd_data[((k_start_r[4]?16:0)+j)*4+:4]==8) fault(8'h03);
        end else if(mode_r==1) for(integer j=0;j<8;j=j+1) begin
          bv_r[output_lane_r][(subword_r?8:0)+j]<=from_bf16(wgt_rd_data[j*16+:16]);
          if(wgt_rd_data[j*16+7+:8]==255) fault(8'h03);
        end else for(integer o=0;o<4;o=o+1) begin
          bv_r[o][key_lane_r]<=from_bf16(wgt_rd_data[((col_r[2]?4:0)+o)*16+:16]);
          if(wgt_rd_data[((col_r[2]?4:0)+o)*16+7+:8]==255) fault(8'h03);
        end
      end else latency_r<=latency_r-1'b1;
      ISSUE_DOT:if(dot_ready) state_r<=WAIT_DOT;
      WAIT_DOT:if(dot_rsp_valid) begin
        for(integer o=0;o<4;o=o+1) tree_r[o]<=dot_data[o*32+:32];
        alu_stage_r<=0;state_r<=ISSUE_ALU;
        if(dot_error || dot_id!=id_r) fault(8'h04);
      end
      ISSUE_ALU:if(all_alu_ready) state_r<=WAIT_ALU;
      WAIT_ALU:if(all_alu_valid) begin
        if(|alu_error || alu_id[0]!=id_r || alu_id[1]!=id_r || alu_id[2]!=id_r || alu_id[3]!=id_r) fault(8'h04);
        else case(alu_stage_r)
          0:begin
            for(integer o=0;o<4;o=o+1) accumulator_r[o]<=alu_data[o];
            if(k_start_r+16>=k_r) begin
              if(mode_r==0) state_r<=READ_SCALE;
              else begin for(integer o=0;o<4;o=o+1) result_r[o]<=alu_data[o];state_r<=WRITE_WORD;end
            end else begin k_start_r<=k_start_r+16;subword_r<=0;state_r<=READ_ACT;end
          end
          1:begin
            for(integer o=0;o<4;o=o+1) begin contribution_r[o]<=alu_data[o];previous_r[o]<=0;end
            if(initialize_r) begin alu_stage_r<=2;state_r<=ISSUE_ALU;end
            else state_r<=READ_PREVIOUS;
          end
          2:begin for(integer o=0;o<4;o=o+1) result_r[o]<=alu_data[o];state_r<=WRITE_WORD;end
          default:fault(8'hff);
        endcase
      end
      READ_SCALE:begin latency_r<=3;state_r<=WAIT_SCALE;end
      WAIT_SCALE:if(latency_r==1) begin
        alu_stage_r<=1;state_r<=ISSUE_ALU;
        for(integer o=0;o<4;o=o+1) begin
          scales_r[o]<=scale_rd_data[o*32+:32];
          if(scale_rd_data[o*32+31] || scale_rd_data[o*32+:31]==0 || scale_rd_data[o*32+23+:8]==255) fault(8'h03);
        end
      end else latency_r<=latency_r-1'b1;
      READ_PREVIOUS:begin latency_r<=3;state_r<=WAIT_PREVIOUS;end
      WAIT_PREVIOUS:if(latency_r==1) begin
        alu_stage_r<=2;state_r<=ISSUE_ALU;
        for(integer o=0;o<4;o=o+1) begin
          previous_r[o]<=dst_rd_data[o*32+:32];if(dst_rd_data[o*32+23+:8]==255) fault(8'h03);
        end
      end else latency_r<=latency_r-1'b1;
      WRITE_WORD:begin
        if(col_r+4>=n_r) begin
          col_r<=0;
          if(row_r==rows_r-1'b1) state_r<=RESPONSE;
          else begin row_r<=row_r+1'b1;state_r<=BEGIN_OUTPUT;end
        end else begin col_r<=col_r+4;state_r<=BEGIN_OUTPUT;end
      end
      RESPONSE:if(rsp_ready) state_r<=IDLE;
      default:fault(8'hff);
    endcase
  end
endmodule
