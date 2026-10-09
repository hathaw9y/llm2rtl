`timescale 1ns/1ps
// Scalar tensor traversal. Memory requests are stable stream requests; responses
// are consumed explicitly, one outstanding in total. Paired metadata uses the
// same destination bank; only the controller can commit destination validity.
module attention_tensor_executor (
    input logic aclk, aresetn,
    input logic cmd_valid, output logic cmd_ready,
    input logic [15:0] cmd_id, input logic [7:0] cmd_opcode,
    input logic [4:0] cmd_src0, cmd_src1, cmd_dst,
    input logic [255:0] cmd_src0_desc, cmd_src1_desc, cmd_dst_desc,
    output logic resp_valid, input logic resp_ready,
    output logic [15:0] resp_id, output logic resp_error,
    output logic [7:0] resp_error_code,
    input logic [5:0] ctx_tokens, ctx_query_count,
    input logic [2:0] ctx_heads, input logic [6:0] ctx_head_dim,
    input logic ctx_causal, input logic [31:0] ctx_qk_factor,
    output logic [4:0] query_lookup_index, input logic [4:0] query_lookup_value,
    output logic src0_read_valid, input logic src0_read_ready,
    output logic [4:0] src0_read_bank, output logic [31:0] src0_read_addr,
    input logic src0_resp_valid, input logic [4:0] src0_resp_bank,
    input logic [127:0] src0_resp_data,
    output logic src1_read_valid, input logic src1_read_ready,
    output logic [4:0] src1_read_bank, output logic [31:0] src1_read_addr,
    input logic src1_resp_valid, input logic [4:0] src1_resp_bank,
    input logic [127:0] src1_resp_data,
    output logic dst_write_valid, input logic dst_write_ready,
    output logic [4:0] dst_write_bank, output logic [31:0] dst_write_addr,
    output logic [127:0] dst_write_data, output logic [15:0] dst_write_strb
);
  import attention_tensor_pkg::*;
  typedef enum logic [7:0] {
    IDLE, CHECK, CLEAR, DISPATCH, RESPONSE, FAULT_HOLD,
    READ_ISSUE, READ_WAIT, ALU_ISSUE, ALU_WAIT, EXP_ISSUE, EXP_WAIT, WRITE_PACK,
    Q_START, Q_CMD, Q_READ, Q_FEED, Q_OUTPUT, Q_CHILD_RESPONSE, Q_NEXT, Q_SCALES,
    P_START, P_A, P_B, P_ACC, P_SCALE_A, P_SCALE_B, P_MUL_SCALE, P_CONVERT,
    P_MUL_DOT, P_ADD, P_NEXT_GROUP, P_EMIT, P_NEXT_OUTPUT,
    K_START, K_A, K_B, K_ACC, K_SCALE_A, K_SCALE_B, K_MUL_SCALE,
    K_CONVERT, K_MUL_DOT, K_FACTOR, K_EMIT, K_NEXT,
    S_START, S_MASK, S_SCORE, S_STORE, S_MAX_NEXT, S_EXP_START, S_SUB,
    S_EXP, S_SUM, S_EXP_NEXT, S_DIV_START, S_DIV, S_EMIT, S_NEXT,
    V_START, V_PROB, V_VALUE, V_SCALE, V_CONVERT, V_DEQUANT,
    V_PRODUCT, V_ADD, V_NEXT_KEY, V_EMIT, V_NEXT
  } state_t;
  state_t state_r, return_r, write_return_r;
  tensor_desc_t a_r,b_r,d_r;
  logic [92:0] unused_dst_descriptor_fields;
  assign unused_dst_descriptor_fields={d_r.valid,d_r.rank,d_r.reserved,d_r.dim0,d_r.data_bytes};
  logic [4:0] bank_a_r,bank_b_r,bank_d_r;
  logic [7:0] opcode_r;
  logic [31:0] row_r,col_r,key_r,head_r,lane_r,group_r,inner_r;
  logic [31:0] total_r,out_index_r,row_length_r,row_count_r;
  logic [31:0] clear_word_r,write_word_r,scale_index_r;
  logic [127:0] pack_r;
  logic [31:0] accumulator_r,temporary_r,operand_r,scale_a_r,scale_b_r;
  logic signed [31:0] dot_r;
  logic [31:0] maximum_r,sum_r,score_r[0:31],exp_r[0:31];
  logic allowed_r[0:31],any_allowed_r;
  logic [15:0] scales_r[0:127];
  logic read_role_r,read_scale_r,read_nibble_r;
  logic [1:0] read_kind_r;
  logic [31:0] read_byte_r,read_value_r;
  logic [4:0] read_bank_r;
  logic [31:0] alu_a_r,alu_b_r,alu_value_r,exp_x_r,exp_value_r;
  logic [2:0] alu_op_r;
  logic alu_ready,alu_resp_valid,alu_error,exp_ready,exp_resp_valid,exp_error;
  logic [31:0] alu_data,exp_data;
  logic [15:0] alu_id,exp_id;
  logic q_cmd_ready,q_input_ready,q_output_valid,q_output_last,q_resp_valid,q_error;
  logic [3:0] q_output_data;
  logic [15:0] q_scale;
  logic [7:0] q_resp_id;
  logic pv_nonzero_r;
  tensor_desc_t cmd_a_w,cmd_b_w,cmd_d_w;
  logic [127:0] selected_response_w;
  logic [31:0] decoded_read_w;
  logic command_legal_w;
  assign cmd_a_w=tensor_desc_t'(cmd_src0_desc);
  assign cmd_b_w=tensor_desc_t'(cmd_src1_desc);
  assign cmd_d_w=tensor_desc_t'(cmd_dst_desc);
  function automatic logic finite(input logic[31:0] unused_x);
    return unused_x[30:23]!=8'hff;
  endfunction
  function automatic logic scale_ok(input logic[31:0] unused_x);
    return !unused_x[31] && unused_x[30:23]!=0 && unused_x[30:23]!=8'hff;
  endfunction
  function automatic logic greater(input logic[31:0] x,y);
    if(x[30:0]==0 && y[30:0]==0) return 1'b0;
    if(x[31]!=y[31]) return !x[31];
    return x[31]?(x[30:0]<y[30:0]):(x[30:0]>y[30:0]);
  endfunction
  function automatic logic[15:0] bf16_round(input logic[31:0] x);
    logic[31:0] unused_rounded;
    unused_rounded=x+32'h7fff+32'(x[16]);return unused_rounded[31:16];
  endfunction
  function automatic logic[31:0] count(input tensor_desc_t unused_x);
    return unused_x.dim0*unused_x.dim1*unused_x.dim2;
  endfunction
  function automatic logic desc_ok(input tensor_desc_t x);
    logic[31:0] n,bytes,sc,off,cap;
    if(!x.valid || x.reserved!='0 || x.rank==0 || x.dim0==0 || x.dim0>256 ||
       x.dim1==0 || x.dim1>256 || x.dim2==0 || x.dim2>64 ||
       (x.rank==1 && (x.dim1!=1 || x.dim2!=1)) || (x.rank==2 && x.dim2!=1)) return 0;
    n=count(x);sc=0;
    case(x.format)
      0:begin if(x.rank<2) return 0;bytes=n*4;end
      1:begin if(x.rank!=3) return 0;bytes=n*2;end
      2:begin if(x.rank!=1) return 0;bytes=n;end
      3:begin if(x.rank<2) return 0;bytes=(n+1)/2;sc=x.dim0;end
      4:begin if(x.rank!=3) return 0;bytes=(n+1)/2;sc=x.dim0*x.dim1;end
      5:begin if(x.rank!=2) return 0;bytes=(n+1)/2;sc=x.dim0*((x.dim1+31)/32);end
      default:return 0;
    endcase
    off=(bytes+15)&32'hfffffff0;cap=(off+sc*2+15)&32'hfffffff0;
    return x.data_bytes==bytes && x.scale_offset==off && x.scale_count==sc && x.capacity_bytes==cap;
  endfunction
  always_comb begin
    command_legal_w=desc_ok(cmd_a_w) && desc_ok(cmd_d_w) && cmd_src0<19 && cmd_dst<19 && cmd_src0!=cmd_dst &&
      ctx_tokens>0 && ctx_tokens<=32 && ctx_query_count>0 && ctx_query_count<=32 && ctx_heads>0 && ctx_heads<=4 &&
      ctx_head_dim>0 && ctx_head_dim<=64 && 32'(ctx_heads)*32'(ctx_head_dim)<=256;
    if(cmd_opcode!=3) command_legal_w=command_legal_w && desc_ok(cmd_b_w) && cmd_src1<19 && cmd_src1!=cmd_dst && cmd_src0!=cmd_src1;
    case(cmd_opcode)
      3:command_legal_w=command_legal_w && cmd_a_w.format==0 && (cmd_d_w.format==3 || cmd_d_w.format==4) &&
        count(cmd_a_w)==count(cmd_d_w) && cmd_a_w.dim0==cmd_d_w.dim0 && cmd_d_w.dim0<=32 &&
        (cmd_d_w.format==3 ? cmd_d_w.dim1*cmd_d_w.dim2<=256 : cmd_d_w.dim1<=4) && cmd_d_w.scale_count<=128;
      4:command_legal_w=command_legal_w && cmd_a_w.format==3 && cmd_a_w.rank==2 && cmd_a_w.dim0<=32 &&
        cmd_b_w.format==5 && cmd_d_w.format==0 && cmd_d_w.rank==2 && cmd_a_w.dim1==cmd_b_w.dim1 &&
        cmd_d_w.dim0==cmd_a_w.dim0 && cmd_d_w.dim1==cmd_b_w.dim0;
      5:command_legal_w=command_legal_w && cmd_a_w.format==3 && cmd_a_w.rank==3 && cmd_b_w.format==4 &&
        cmd_a_w.dim0==32'(ctx_tokens) && cmd_b_w.dim0==cmd_a_w.dim0 && cmd_a_w.dim1==32'(ctx_heads) &&
        cmd_b_w.dim1==cmd_a_w.dim1 && cmd_a_w.dim2==32'(ctx_head_dim) && cmd_b_w.dim2==cmd_a_w.dim2 &&
        cmd_d_w.format==0 && cmd_d_w.rank==3 && cmd_d_w.dim0==32'(ctx_query_count) &&
        cmd_d_w.dim1==32'(ctx_heads) && cmd_d_w.dim2==32'(ctx_tokens) && scale_ok(ctx_qk_factor);
      6:command_legal_w=command_legal_w && cmd_a_w.format==0 && cmd_a_w.rank==3 && cmd_b_w.format==2 &&
        cmd_d_w.format==1 && cmd_a_w.dim0==32'(ctx_query_count) && cmd_a_w.dim1==32'(ctx_heads) &&
        cmd_a_w.dim2==32'(ctx_tokens) && cmd_b_w.dim0==32'(ctx_tokens) && count(cmd_d_w)==count(cmd_a_w) &&
        cmd_d_w.dim0==cmd_a_w.dim0 && cmd_d_w.dim1==cmd_a_w.dim1 && cmd_d_w.dim2==cmd_a_w.dim2;
      7:command_legal_w=command_legal_w && cmd_a_w.format==1 && cmd_b_w.format==4 && cmd_d_w.format==0 && cmd_d_w.rank==2 &&
        cmd_a_w.dim0==32'(ctx_query_count) && cmd_a_w.dim1==32'(ctx_heads) && cmd_a_w.dim2==32'(ctx_tokens) &&
        cmd_b_w.dim0==32'(ctx_tokens) && cmd_b_w.dim1==32'(ctx_heads) && cmd_b_w.dim2==32'(ctx_head_dim) &&
        cmd_d_w.dim0==32'(ctx_query_count) && cmd_d_w.dim1==32'(ctx_heads)*32'(ctx_head_dim);
      default:command_legal_w=0;
    endcase
  end
  assign cmd_ready=aresetn && state_r==IDLE;
  assign resp_valid=aresetn && state_r==RESPONSE;
  assign query_lookup_index=5'(row_r);
  assign src0_read_valid=aresetn && state_r==READ_ISSUE && !read_role_r;
  assign src1_read_valid=aresetn && state_r==READ_ISSUE && read_role_r;
  assign src0_read_bank=read_bank_r;assign src1_read_bank=read_bank_r;
  assign src0_read_addr=read_byte_r>>4;assign src1_read_addr=read_byte_r>>4;
  assign selected_response_w=read_role_r?src1_resp_data:src0_resp_data;
  always_comb begin
    decoded_read_w=0;
    case(read_kind_r)
      0:decoded_read_w=32'(selected_response_w>>(8*read_byte_r[3:0]));
      1:decoded_read_w={16'(selected_response_w>>(8*read_byte_r[3:0])),16'b0};
      2:decoded_read_w={24'b0,8'(selected_response_w>>(8*read_byte_r[3:0]))};
      3:decoded_read_w=32'($signed(4'(selected_response_w>>(8*read_byte_r[3:0]+4*32'(read_nibble_r)))));
    endcase
  end
  assign dst_write_valid=aresetn && (state_r==CLEAR || state_r==WRITE_PACK);
  assign dst_write_bank=bank_d_r;
  assign dst_write_addr=state_r==CLEAR?clear_word_r:write_word_r;
  assign dst_write_data=state_r==CLEAR?128'b0:pack_r;
  assign dst_write_strb=16'hffff;
  attention_fp32_alu u_alu(.aclk,.aresetn,.cmd_valid(state_r==ALU_ISSUE),.cmd_ready(alu_ready),.cmd_id(16'b0),
    .cmd_op(alu_op_r),.cmd_a(alu_a_r),.cmd_b(alu_b_r),.resp_valid(alu_resp_valid),.resp_ready(state_r==ALU_WAIT),
    .resp_id(alu_id),.resp_data(alu_data),.resp_error(alu_error));
  attention_exp_neg u_exp(.aclk,.aresetn,.cmd_valid(state_r==EXP_ISSUE),.cmd_ready(exp_ready),.cmd_id(16'b0),
    .cmd_x(exp_x_r),.resp_valid(exp_resp_valid),.resp_ready(state_r==EXP_WAIT),.resp_id(exp_id),.resp_data(exp_data),.resp_error(exp_error));
  attention_int4_quantizer #(.MAX_ELEMENTS(256),.ID_WIDTH(8)) u_quantizer(.aclk,.aresetn,
    .cmd_valid(state_r==Q_CMD),.cmd_ready(q_cmd_ready),.cmd_id(8'b0),.cmd_elements(9'(row_length_r)),
    .s_axis_value_tvalid(state_r==Q_FEED),.s_axis_value_tready(q_input_ready),.s_axis_value_tdata(read_value_r),
    .m_axis_quant_tvalid(q_output_valid),.m_axis_quant_tready(state_r==Q_OUTPUT),.m_axis_quant_tdata(q_output_data),
    .m_axis_quant_tscale(q_scale),.m_axis_quant_tlast(q_output_last),.resp_valid(q_resp_valid),
    .resp_ready(state_r==Q_CHILD_RESPONSE || (state_r==Q_OUTPUT && q_error)),.resp_id(q_resp_id),.resp_error(q_error));
  task automatic fail(input logic[7:0] code);
    resp_error<=1;resp_error_code<=code;state_r<=RESPONSE;
  endtask
  task automatic read_element(input logic role,input tensor_desc_t unused_d,input logic[4:0] bank,input logic[31:0] index,input state_t next);
    read_role_r<=role;read_bank_r<=bank;read_scale_r<=0;read_nibble_r<=index[0];
    if(unused_d.format==0) begin read_kind_r<=0;read_byte_r<=index*4;end
    else if(unused_d.format==1) begin read_kind_r<=1;read_byte_r<=index*2;end
    else if(unused_d.format==2) begin read_kind_r<=2;read_byte_r<=index;end
    else begin read_kind_r<=3;read_byte_r<=index>>1;end
    return_r<=next;state_r<=READ_ISSUE;
  endtask
  task automatic read_scale(input logic role,input tensor_desc_t unused_d,input logic[4:0] bank,input logic[31:0] index,input state_t next);
    read_role_r<=role;read_bank_r<=bank;read_scale_r<=1;read_nibble_r<=0;read_kind_r<=1;
    read_byte_r<=unused_d.scale_offset+index*2;return_r<=next;state_r<=READ_ISSUE;
  endtask
  task automatic math(input logic[2:0] op,input logic[31:0] a,b,input state_t next);
    alu_op_r<=op;alu_a_r<=a;alu_b_r<=b;return_r<=next;state_r<=ALU_ISSUE;
  endtask
  task automatic emit(input logic[31:0] value,input logic[1:0] kind,input state_t next);
    logic[31:0] perword;
    perword=kind==0?4:kind==1?8:32;
    if(kind==0)pack_r[32*out_index_r[1:0]+:32]<=value;
    else if(kind==1)pack_r[16*out_index_r[2:0]+:16]<=value[15:0];
    else pack_r[4*out_index_r[4:0]+:4]<=value[3:0];
    out_index_r<=out_index_r+1;
    if((out_index_r+1)%perword==0 || out_index_r+1==total_r)begin
      write_word_r<=out_index_r/perword;write_return_r<=next;state_r<=WRITE_PACK;
    end else state_r<=next;
  endtask
  always_ff @(posedge aclk)begin
    if(!aresetn)begin
      state_r<=IDLE;return_r<=IDLE;write_return_r<=IDLE;
      a_r<='0;b_r<='0;d_r<='0;bank_a_r<=0;bank_b_r<=0;bank_d_r<=0;opcode_r<=0;
      resp_id<=0;resp_error<=0;resp_error_code<=0;row_r<=0;col_r<=0;key_r<=0;head_r<=0;lane_r<=0;group_r<=0;inner_r<=0;
      total_r<=0;out_index_r<=0;row_length_r<=0;row_count_r<=0;clear_word_r<=0;write_word_r<=0;scale_index_r<=0;pack_r<=0;pv_nonzero_r<=0;
      accumulator_r<=0;temporary_r<=0;operand_r<=0;scale_a_r<=0;scale_b_r<=0;dot_r<=0;maximum_r<=0;sum_r<=0;any_allowed_r<=0;
      read_role_r<=0;read_scale_r<=0;read_nibble_r<=0;read_kind_r<=0;read_byte_r<=0;read_value_r<=0;read_bank_r<=0;
      alu_a_r<=0;alu_b_r<=0;alu_value_r<=0;exp_x_r<=0;exp_value_r<=0;alu_op_r<=0;
      // Row buffers are written before use; reset discards their validity.
    end else begin
      case(state_r)
        IDLE:if(cmd_valid && cmd_ready)begin
          a_r<=cmd_a_w;b_r<=cmd_b_w;d_r<=cmd_d_w;bank_a_r<=cmd_src0;bank_b_r<=cmd_src1;bank_d_r<=cmd_dst;
          opcode_r<=cmd_opcode;resp_id<=cmd_id;resp_error<=0;resp_error_code<=0;
          row_r<=0;col_r<=0;head_r<=0;key_r<=0;lane_r<=0;inner_r<=0;group_r<=0;out_index_r<=0;pack_r<=0;clear_word_r<=0;
          total_r<=count(cmd_d_w);
          if(command_legal_w)state_r<=CLEAR;else fail(8'd2);
        end
        CLEAR:if(dst_write_valid && dst_write_ready)begin
          if((clear_word_r+1)*16==d_r.capacity_bytes)state_r<=DISPATCH;
          else clear_word_r<=clear_word_r+1;
        end
        DISPATCH:case(opcode_r)
          3:state_r<=Q_START;4:state_r<=P_START;5:state_r<=K_START;6:state_r<=S_START;7:state_r<=V_START;default:fail(8'd2);
        endcase
        READ_ISSUE:if(read_role_r?src1_read_ready:src0_read_ready)state_r<=READ_WAIT;
        READ_WAIT:if(read_role_r?src1_resp_valid:src0_resp_valid)begin
          if((read_role_r?src1_resp_bank:src0_resp_bank)!=read_bank_r)state_r<=FAULT_HOLD;
          else if((read_scale_r && !scale_ok(decoded_read_w)) ||
              (read_kind_r==0 && !finite(decoded_read_w)) ||
              (read_kind_r==1 && !read_scale_r && (!finite(decoded_read_w) || decoded_read_w[31] || decoded_read_w>32'h3f800000)) ||
              (read_kind_r==3 && decoded_read_w==32'hfffffff8))fail(8'd4);
          else begin read_value_r<=decoded_read_w;state_r<=return_r;end
        end
        ALU_ISSUE:if(alu_ready)state_r<=ALU_WAIT;
        ALU_WAIT:if(alu_resp_valid)begin
          if(alu_id!=0)state_r<=FAULT_HOLD;else if(alu_error)fail(8'd4);else begin alu_value_r<=alu_data;state_r<=return_r;end
        end
        EXP_ISSUE:if(exp_ready)state_r<=EXP_WAIT;
        EXP_WAIT:if(exp_resp_valid)begin
          if(exp_id!=0)state_r<=FAULT_HOLD;else if(exp_error)fail(8'd4);else begin exp_value_r<=exp_data;state_r<=return_r;end
        end
        WRITE_PACK:if(dst_write_valid && dst_write_ready)begin pack_r<=0;state_r<=write_return_r;end
        Q_START:begin
          row_length_r<=d_r.format==3?d_r.dim1*d_r.dim2:d_r.dim2;
          row_count_r<=d_r.scale_count;lane_r<=0;state_r<=Q_CMD;
        end
        Q_CMD:if(q_cmd_ready)state_r<=Q_READ;
        Q_READ:read_element(0,a_r,bank_a_r,row_r*row_length_r+lane_r,Q_FEED);
        Q_FEED:if(q_input_ready)begin
          if(lane_r+1==row_length_r)begin lane_r<=0;state_r<=Q_OUTPUT;end
          else begin lane_r<=lane_r+1;state_r<=Q_READ;end
        end
        Q_OUTPUT:begin
          if(q_output_valid)begin
            scales_r[7'(row_r)]<=q_scale;
            emit({28'b0,q_output_data},2,q_output_last?Q_CHILD_RESPONSE:Q_OUTPUT);
          end
          if(q_resp_valid && q_error)begin
            if(q_resp_id!=0)state_r<=FAULT_HOLD;else fail(8'd4);
          end
        end
        Q_CHILD_RESPONSE:if(q_resp_valid)begin
          if(q_resp_id!=0)state_r<=FAULT_HOLD;else if(q_error)fail(8'd4);else state_r<=Q_NEXT;
        end
        Q_NEXT:if(row_r+1==row_count_r)begin scale_index_r<=0;pack_r<=0;state_r<=Q_SCALES;end
          else begin row_r<=row_r+1;lane_r<=0;state_r<=Q_CMD;end
        Q_SCALES:begin
          pack_r[16*scale_index_r[2:0]+:16]<=scales_r[7'(scale_index_r)];
          if(scale_index_r+1==row_count_r || scale_index_r[2:0]==7)begin
            write_word_r<=(d_r.scale_offset>>4)+(scale_index_r>>3);
            write_return_r<=scale_index_r+1==row_count_r?RESPONSE:Q_SCALES;state_r<=WRITE_PACK;
          end
          scale_index_r<=scale_index_r+1;
        end
        P_START:begin dot_r<=0;inner_r<=0;group_r<=0;accumulator_r<=0;state_r<=P_A;end
        P_A:read_element(0,a_r,bank_a_r,row_r*a_r.dim1+group_r*32+inner_r,P_B);
        P_B:begin operand_r<=read_value_r;read_element(1,b_r,bank_b_r,col_r*b_r.dim1+group_r*32+inner_r,P_ACC);end
        P_ACC:begin
          dot_r<=dot_r+$signed(operand_r)*$signed(read_value_r);
          if(inner_r==31 || group_r*32+inner_r+1==a_r.dim1)state_r<=P_SCALE_A;
          else begin inner_r<=inner_r+1;state_r<=P_A;end
        end
        P_SCALE_A:read_scale(0,a_r,bank_a_r,row_r,P_SCALE_B);
        P_SCALE_B:begin scale_a_r<=read_value_r;read_scale(1,b_r,bank_b_r,col_r*((b_r.dim1+31)/32)+group_r,P_MUL_SCALE);end
        P_MUL_SCALE:math(1,scale_a_r,read_value_r,P_CONVERT);
        P_CONVERT:begin temporary_r<=alu_value_r;math(3,32'(dot_r),0,P_MUL_DOT);end
        P_MUL_DOT:math(1,alu_value_r,temporary_r,P_ADD);
        P_ADD:math(0,accumulator_r,alu_value_r,P_NEXT_GROUP);
        P_NEXT_GROUP:begin
          accumulator_r<=alu_value_r;
          if((group_r+1)*32>=a_r.dim1)state_r<=P_EMIT;
          else begin group_r<=group_r+1;inner_r<=0;dot_r<=0;state_r<=P_A;end
        end
        P_EMIT:emit(accumulator_r,0,P_NEXT_OUTPUT);
        P_NEXT_OUTPUT:if(out_index_r==total_r)state_r<=RESPONSE;
          else if(col_r+1==d_r.dim1)begin col_r<=0;row_r<=row_r+1;state_r<=P_START;end
          else begin col_r<=col_r+1;state_r<=P_START;end
        K_START:begin
          if({1'b0,query_lookup_value}>=ctx_tokens)fail(8'd2);else begin inner_r<=0;dot_r<=0;state_r<=K_A;end
        end
        K_A:read_element(0,a_r,bank_a_r,(32'(query_lookup_value)*32'(ctx_heads)+head_r)*32'(ctx_head_dim)+inner_r,K_B);
        K_B:begin operand_r<=read_value_r;read_element(1,b_r,bank_b_r,(key_r*32'(ctx_heads)+head_r)*32'(ctx_head_dim)+inner_r,K_ACC);end
        K_ACC:begin
          dot_r<=dot_r+$signed(operand_r)*$signed(read_value_r);
          if(inner_r+1==32'(ctx_head_dim))state_r<=K_SCALE_A;else begin inner_r<=inner_r+1;state_r<=K_A;end
        end
        K_SCALE_A:read_scale(0,a_r,bank_a_r,32'(query_lookup_value),K_SCALE_B);
        K_SCALE_B:begin scale_a_r<=read_value_r;read_scale(1,b_r,bank_b_r,key_r*32'(ctx_heads)+head_r,K_MUL_SCALE);end
        K_MUL_SCALE:math(1,scale_a_r,read_value_r,K_CONVERT);
        K_CONVERT:begin temporary_r<=alu_value_r;math(3,32'(dot_r),0,K_MUL_DOT);end
        K_MUL_DOT:math(1,alu_value_r,temporary_r,K_FACTOR);
        K_FACTOR:math(1,alu_value_r,ctx_qk_factor,K_EMIT);
        K_EMIT:emit(alu_value_r,0,K_NEXT);
        K_NEXT:if(out_index_r==total_r)state_r<=RESPONSE;
          else if(key_r+1==32'(ctx_tokens))begin
            key_r<=0;if(head_r+1==32'(ctx_heads))begin head_r<=0;row_r<=row_r+1;end else head_r<=head_r+1;state_r<=K_START;
          end else begin key_r<=key_r+1;state_r<=K_START;end
        S_START:begin
          if({1'b0,query_lookup_value}>=ctx_tokens)fail(8'd2);else begin key_r<=0;any_allowed_r<=0;maximum_r<=0;sum_r<=0;state_r<=S_MASK;end
        end
        S_MASK:read_element(1,b_r,bank_b_r,key_r,S_SCORE);
        S_SCORE:begin
          if(read_value_r>1)fail(8'd4);
          else if(read_value_r==1 && (!ctx_causal || key_r<=32'(query_lookup_value)))begin
            allowed_r[5'(key_r)]<=1;read_element(0,a_r,bank_a_r,(row_r*32'(ctx_heads)+head_r)*32'(ctx_tokens)+key_r,S_STORE);
          end else begin allowed_r[5'(key_r)]<=0;score_r[5'(key_r)]<=0;state_r<=S_MAX_NEXT;end
        end
        S_STORE:begin
          score_r[5'(key_r)]<=read_value_r;
          if(!any_allowed_r || greater(read_value_r,maximum_r))maximum_r<=read_value_r;
          any_allowed_r<=1;state_r<=S_MAX_NEXT;
        end
        S_MAX_NEXT:if(key_r+1==32'(ctx_tokens))begin key_r<=0;state_r<=S_EXP_START;end else begin key_r<=key_r+1;state_r<=S_MASK;end
        S_EXP_START:if(allowed_r[5'(key_r)])math(4,score_r[5'(key_r)],maximum_r,S_SUB);
          else begin exp_r[5'(key_r)]<=0;state_r<=S_EXP_NEXT;end
        S_SUB:begin exp_x_r<=alu_value_r;return_r<=S_EXP;state_r<=EXP_ISSUE;end
        S_EXP:begin exp_r[5'(key_r)]<=exp_value_r;math(0,sum_r,exp_value_r,S_SUM);end
        S_SUM:begin sum_r<=alu_value_r;state_r<=S_EXP_NEXT;end
        S_EXP_NEXT:if(key_r+1==32'(ctx_tokens))begin key_r<=0;state_r<=S_DIV_START;end else begin key_r<=key_r+1;state_r<=S_EXP_START;end
        S_DIV_START:if(allowed_r[5'(key_r)] && any_allowed_r)math(2,exp_r[5'(key_r)],sum_r,S_DIV);
          else emit(0,1,S_NEXT);
        S_DIV:state_r<=S_EMIT;
        S_EMIT:emit({16'b0,bf16_round(alu_value_r)},1,S_NEXT);
        S_NEXT:if(out_index_r==total_r)state_r<=RESPONSE;
          else if(key_r+1==32'(ctx_tokens))begin
            key_r<=0;if(head_r+1==32'(ctx_heads))begin head_r<=0;row_r<=row_r+1;end else head_r<=head_r+1;state_r<=S_START;
          end else begin key_r<=key_r+1;state_r<=S_DIV_START;end
        V_START:begin key_r<=0;accumulator_r<=0;state_r<=V_PROB;end
        V_PROB:read_element(0,a_r,bank_a_r,(row_r*32'(ctx_heads)+head_r)*32'(ctx_tokens)+key_r,V_VALUE);
        V_VALUE:if(read_value_r[30:0]==0)begin pv_nonzero_r<=0;state_r<=V_NEXT_KEY;end
          else begin pv_nonzero_r<=1;temporary_r<=read_value_r;read_element(1,b_r,bank_b_r,(key_r*32'(ctx_heads)+head_r)*32'(ctx_head_dim)+lane_r,V_SCALE);end
        V_SCALE:begin operand_r<=read_value_r;read_scale(1,b_r,bank_b_r,key_r*32'(ctx_heads)+head_r,V_CONVERT);end
        V_CONVERT:begin scale_b_r<=read_value_r;math(3,operand_r,0,V_DEQUANT);end
        V_DEQUANT:math(1,alu_value_r,scale_b_r,V_PRODUCT);
        V_PRODUCT:math(1,temporary_r,alu_value_r,V_ADD);
        V_ADD:math(0,accumulator_r,alu_value_r,V_NEXT_KEY);
        V_NEXT_KEY:begin
          begin
            // A skipped zero probability must not reuse an earlier ALU result.
            if(pv_nonzero_r)accumulator_r<=alu_value_r;
            if(key_r+1==32'(ctx_tokens))state_r<=V_EMIT;else begin key_r<=key_r+1;state_r<=V_PROB;end
          end
        end
        V_EMIT:emit(accumulator_r,0,V_NEXT);
        V_NEXT:if(out_index_r==total_r)state_r<=RESPONSE;
          else if(lane_r+1==32'(ctx_head_dim))begin
            lane_r<=0;if(head_r+1==32'(ctx_heads))begin head_r<=0;row_r<=row_r+1;end else head_r<=head_r+1;state_r<=V_START;
          end else begin lane_r<=lane_r+1;state_r<=V_START;end
        RESPONSE:if(resp_valid && resp_ready)state_r<=IDLE;
        FAULT_HOLD:state_r<=FAULT_HOLD;
        default:state_r<=FAULT_HOLD;
      endcase
      // An unsolicited response cannot establish memory quiescence. Do not
      // manufacture completion or allow the parent to release this owner.
      if((src0_resp_valid && (state_r!=READ_WAIT || read_role_r)) ||
         (src1_resp_valid && (state_r!=READ_WAIT || !read_role_r)))state_r<=FAULT_HOLD;
    end
  end
endmodule
