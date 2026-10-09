module smollm2_quantization_executor(
 input logic clk,
 input logic resetn,
 input logic cmd_valid,
 input logic [3:0] cmd_opcode,
 input logic [111:0] cmd_payload,
 input logic [11:0] cmd_bank_ids,
 input logic [31:0] cmd_transaction_id,
 input logic [95:0] cmd_generations,
 output logic cmd_ready,
 input logic [2:0] cmd_desc_present,
 input logic [14:0] cmd_profiles,
 input logic [32:0] cmd_rows,
 input logic [47:0] cmd_cols,
 input logic [29:0] cmd_positions,
 input logic [14:0] cmd_layers,
 input logic [95:0] cmd_desc_generations,
 input logic [2:0] cmd_data_valid,
 input logic [2:0] cmd_scale_valid,
 input logic [2:0] cmd_desc_busy,
 input logic [14:0] cmd_desc_owner,
 input logic cmd_b7_static_valid,
 input logic [63:0] cmd_embedding_lanes,
 input logic [31:0] cmd_embedding_lane_valid,
 output logic [4:0] a_role,
 output logic [4:0] b_role,
 output logic [4:0] c_role,
 output logic a_rd_valid,
 output logic [3:0] a_rd_bank,
 output logic [18:0] a_rd_address,
 output logic a_rd_wide,
 output logic b_rd_valid,
 output logic [3:0] b_rd_bank,
 output logic [18:0] b_rd_address,
 output logic b_rd_wide,
 input logic a_rd_ready,
 input logic a_rd_resp_valid,
 input logic [127:0] a_rd_data,
 input logic b_rd_ready,
 input logic b_rd_resp_valid,
 input logic [127:0] b_rd_data,
 output logic c_wr_valid,
 output logic [3:0] c_wr_bank,
 output logic [18:0] c_wr_address,
 output logic [127:0] c_wr_data,
 output logic [15:0] c_wr_strb,
 input logic c_wr_ready,
 output logic resp_valid,
 output logic [31:0] resp_transaction_id,
 output logic [2:0] resp_used_bank_mask,
 output logic [1:0] resp_used_bank_count,
 output logic [11:0] resp_bank_ids,
 output logic [95:0] resp_generations,
 output logic [7:0] resp_error_code,
 input logic resp_ready,
 output logic dst_begin_valid,
 output logic [3:0] dst_begin_bank,
 output logic [31:0] dst_begin_accepted_generation,
 output logic [31:0] dst_begin_generation,
 output logic [4:0] dst_begin_profile,
 output logic [10:0] dst_begin_rows,
 output logic [15:0] dst_begin_cols,
 output logic [9:0] dst_begin_position,
 output logic [4:0] dst_begin_layer,
 input logic dst_begin_ready,
 input logic [7:0] dst_begin_error_code,
 output logic dst_invalidate_valid,
 output logic [3:0] dst_invalidate_bank,
 output logic [31:0] dst_invalidate_generation,
 input logic dst_invalidate_ready
);
 // Streaming, bounded four-beat native credits; no full-tensor staging.
 typedef enum logic[4:0] {IDLE,CHECK,BEGIN_DST,STATIC_LOAD,STATIC_VALIDATE,
  REDUCE,SCALE_GEN,SCALE_DRAIN,SCALE_WRITE,SCALE_WRITE_DRAIN,
  QUANT_STREAM,QUANT_DRAIN,DQ_SCALE,DQ_STREAM,DQ_DRAIN,
  ERROR_DRAIN,INVALIDATE,RESPONSE} state_t;
 state_t state_r;
 logic[3:0]opcode_r;logic[111:0]payload_r;logic[11:0]banks_r;
 logic[31:0]txn_r;logic[95:0]gens_r,desc_gens_r;
 logic[14:0]profiles_r,layers_r,owners_r;logic[32:0]rows_desc_r;
 logic[47:0]cols_desc_r;logic[29:0]positions_r;
 logic[2:0]present_r,data_ready_r,scale_ready_r,busy_r;
 logic static_valid_r;logic[63:0]embedding_lanes_r;logic[31:0]embedding_valid_r;
 logic[2:0]mode_r;logic[7:0]error_r;logic begun_r;
 integer rows_r,mstart_r,k_r,length_r,query_r,layer_r,groups_r,width_r,padded_r;
 integer scale_count_r,scale_words_r,scale_base_r,source_words_r,source_base_r;
 integer src_issued_r,src_returned_r,src_consumed_r,table_issued_r,table_returned_r,table_consumed_r;
 logic[127:0]src_fifo_r[0:3],table_fifo_r[0:3];
 integer src_count_w,table_count_w,src_credit_w,table_credit_w;
 logic[1:0]src_sub_r;integer elem_r,scale_issue_r,scale_retired_r,scale_write_r,dq_row_r;
 logic[15:0]max_r[0:17];logic[31:0]scales_r[0:17];logic[31:0]dq_scale_r;
 logic src_pop_w,table_pop_w,reduce_fire_w,reduce_bad_w;
 logic[127:0]src_head_w,table_head_w;logic[15:0]reduce_max_w;
 logic [4:0] group_w;
 logic [5:0] relative_row_r;logic [13:0] row_column_r;
 logic [3:0] head_index_r;logic [10:0] head_feature_r;
 logic bundle_fire_w;logic [3:0] selected_p_w;
 logic q_sv,q_sr,q_mv,q_mr,q_unsigned;logic[63:0]q_bf16;
 logic[127:0]q_scale,q_quotient;logic[3:0]q_mask,q_mmask,q_error;
 logic[31:0]q_int8;logic[95:0]q_tag,q_mtag;
 logic d_sv,d_sr,d_mv,d_mr;logic[31:0]d_int8;
 logic[127:0]d_scale;logic[3:0]d_mask,d_mmask,d_error;logic[63:0]d_bf16;logic[95:0]d_tag,d_mtag;
 integer q_pending_r,d_pending_r;
 logic qhold_r,dhold_r;logic[63:0]qhold_bf16_r;logic[127:0]qhold_scale_r,dhold_scale_r;
 logic[3:0]qhold_mask_r,dhold_mask_r;logic[95:0]qhold_tag_r,dhold_tag_r;
 logic qhold_unsigned_r;logic[31:0]dhold_int8_r;
 logic ahold_r,bhold_r;logic[18:0]ahold_address_r,bhold_address_r;
 // Payload capacity exactlytwo128-bit words; address/strobes are control metadata.
 logic[127:0]write_data_r[0:1];logic[18:0]write_address_r[0:1];logic[15:0]write_strb_r[0:1];
 logic[1:0]write_valid_r;logic write_read_r,write_fill_r;integer pack_bytes_r;
 logic pack_space_w,append_w,metadata_w;logic[63:0]append_data_w;logic[31:0]append_offset_w;
 integer append_bytes_w;logic[127:0]metadata_data_w;
 logic[7:0]descriptor_error_w;logic static_mode_w,dynamic_mode_w;
 logic numeric_fault_w,drain_w;
 function automatic logic valid_scale(input logic[31:0]x);valid_scale=!x[31]&&x[30:0]!=0&&x[30:23]!=8'hff;endfunction
 assign group_w=mode_r==0?{4'd0,relative_row_r[4]}:
  (mode_r==1||mode_r==4)?((groups_r==2?{head_index_r,1'b0}:{1'b0,head_index_r})+{4'd0,relative_row_r[4]}):
  mode_r==2?{1'b0,head_index_r}:mode_r==3?row_column_r[8:4]:5'd0;
 for(genvar lane=0;lane<4;lane=lane+1)begin:p_selection
  assign selected_p_w[lane]=(head_feature_r+11'(lane)<11'(length_r))&&(head_feature_r+11'(lane)<=11'(query_r)+11'(relative_row_r));
 end
 assign static_mode_w=opcode_r==13&&(mode_r==2||mode_r==3);
 assign dynamic_mode_w=opcode_r==13&&(mode_r==0||mode_r==1||mode_r==4);
 assign cmd_ready=resetn&&state_r==IDLE;
 assign resp_valid=state_r==RESPONSE;assign resp_transaction_id=txn_r;
 assign resp_bank_ids=banks_r;assign resp_generations=gens_r;assign resp_error_code=error_r;
 assign resp_used_bank_mask=static_mode_w?3'b111:3'b101;
 assign resp_used_bank_count=static_mode_w?2'd3:2'd2;
 assign a_role=opcode_r==14?5'd24:5'd21;assign b_role=static_mode_w?5'd22:5'd0;
 assign c_role=opcode_r==14?5'd25:5'd23;
 assign a_rd_bank=banks_r[3:0];assign b_rd_bank=banks_r[7:4];assign c_wr_bank=banks_r[11:8];
 assign a_rd_wide=0;assign b_rd_wide=0;
 assign dst_begin_valid=state_r==BEGIN_DST;assign dst_begin_bank=banks_r[11:8];
 assign dst_begin_accepted_generation=gens_r[95:64];assign dst_begin_generation=gens_r[95:64]+32'd1;
 assign dst_begin_profile=opcode_r==14?5'd1:mode_r==0?5'd21:mode_r==1?5'd23:mode_r==2?5'd12:mode_r==3?5'd14:5'd22;
 assign dst_begin_rows=11'(rows_r);assign dst_begin_cols=16'(opcode_r==14?576:mode_r==0?k_r:mode_r==1?576:mode_r==4?length_r:192);
 assign dst_begin_position=10'(opcode_r==13&&mode_r==4?query_r:0);
 assign dst_begin_layer=5'(static_mode_w?layer_r:0);
 assign dst_invalidate_valid=state_r==INVALIDATE;assign dst_invalidate_bank=banks_r[11:8];
 assign dst_invalidate_generation=gens_r[95:64]+(begun_r?32'd1:32'd0);
 assign src_count_w=src_returned_r-src_consumed_r;assign table_count_w=table_returned_r-table_consumed_r;
 assign src_credit_w=src_issued_r-src_consumed_r;assign table_credit_w=table_issued_r-table_consumed_r;
 assign src_head_w=src_fifo_r[(src_consumed_r&3)];assign table_head_w=table_fifo_r[(table_consumed_r&3)];
 always_comb begin
  descriptor_error_w=0;
  if(opcode_r!=13&&opcode_r!=14 || payload_r[111:52]!=0)descriptor_error_w=1;
  else if(mode_r>4 || opcode_r==14&&mode_r!=0)descriptor_error_w=1;
  else if(banks_r[3:0]==banks_r[11:8])descriptor_error_w=2;
  else if((opcode_r==14&&banks_r!=12'h003) ||
   (opcode_r==13&&mode_r==0&&(!(banks_r[3:0]==2||banks_r[3:0]==10||banks_r[3:0]==11)||banks_r[11:8]!=13||banks_r[7:4]!=0)) ||
   (opcode_r==13&&mode_r==1&&banks_r!=12'he04)||(opcode_r==13&&mode_r==2&&banks_r!=12'h875)||
   (opcode_r==13&&mode_r==3&&banks_r!=12'h976)||(opcode_r==13&&mode_r==4&&banks_r!=12'hd0a))descriptor_error_w=2;
  else if(!present_r[0]||static_mode_w&&!present_r[1])descriptor_error_w=2;
  else if(!busy_r[0]||!busy_r[2]||owners_r[4:0]!=a_role||owners_r[14:10]!=c_role||
   gens_r[31:0]==0||gens_r[31:0]!=desc_gens_r[31:0]||gens_r[95:64]!=desc_gens_r[95:64]||
   static_mode_w&&(!busy_r[1]||owners_r[9:5]!=b_role||gens_r[63:32]==0||gens_r[63:32]!=desc_gens_r[63:32])||gens_r[95:64]==32'hffffffff)descriptor_error_w=7;
  else if(!data_ready_r[0]||opcode_r==14&&!scale_ready_r[0]||static_mode_w&&!static_valid_r)descriptor_error_w=4;
  else if(rows_r<1||rows_r>32||mstart_r+rows_r>32||integer'(rows_desc_r[10:0])<mstart_r+rows_r||integer'(rows_desc_r[10:0])>32)descriptor_error_w=3;
  else if(static_mode_w&&profiles_r[9:5]!=11)descriptor_error_w=2;
  else if(opcode_r==14 && (profiles_r[4:0]!=6||integer'(rows_desc_r[10:0])!=rows_r||integer'(cols_desc_r[15:0])!=576))descriptor_error_w=3;
  else if(opcode_r==14 && (mstart_r!=0||k_r!=576||length_r!=0||query_r!=0||layer_r!=0))descriptor_error_w=3;
  else if(opcode_r==13&&mode_r==0&&(k_r!=576&&k_r!=1536||integer'(cols_desc_r[15:0])!=k_r||length_r!=0||query_r!=0||layer_r!=0))descriptor_error_w=3;
  else if(opcode_r==13&&mode_r==0&&(profiles_r[4:0]!=(banks_r[3:0]==2?3:banks_r[3:0]==10?18:19)))descriptor_error_w=2;
  else if(opcode_r==13&&mode_r==0&&k_r!=(banks_r[3:0]==10?1536:576))descriptor_error_w=3;
  else if(opcode_r==13&&mode_r>=1&&mode_r<=3&&(k_r!=64||mstart_r!=0||length_r!=0||query_r!=0||layer_r>29||mode_r==1&&layer_r!=0||
   integer'(cols_desc_r[15:0])!=(mode_r==1?576:192)))descriptor_error_w=3;
  else if(opcode_r==13&&mode_r>=1&&mode_r<=3&&profiles_r[4:0]!=(mode_r==1?7:mode_r==2?8:10))descriptor_error_w=2;
  else if(opcode_r==13&&mode_r==4&&(profiles_r[4:0]!=17||length_r<1||length_r>1024||k_r!=length_r||mstart_r!=0||layer_r!=0||
   query_r+integer'(rows_desc_r[10:0])>length_r||integer'(cols_desc_r[15:0])!=length_r||integer'(positions_r[9:0])!=query_r))descriptor_error_w=3;
  else if((opcode_r!=13||mode_r!=4)&&positions_r[9:0]!=0||layers_r[4:0]!=0)descriptor_error_w=3;
  if(opcode_r==14&&descriptor_error_w==0)for(integer r=0;r<32;r=r+1)if(r<rows_r&&!embedding_valid_r[r])descriptor_error_w=4;
 end
 always_comb begin
  a_rd_valid=((state_r==REDUCE||state_r==QUANT_STREAM||state_r==DQ_STREAM)&&src_issued_r<source_words_r||state_r==DQ_SCALE&&src_issued_r<1)&&src_credit_w<4;
  a_rd_address=19'(state_r==DQ_SCALE?(294912/16+dq_row_r):source_base_r/16+src_issued_r);
  b_rd_valid=state_r==STATIC_LOAD&&table_issued_r<(mode_r==2?1:3)&&table_credit_w<4;
  b_rd_address=19'((4096+layer_r*64+(mode_r==3?16:0))/16+table_issued_r);
  if(state_r==ERROR_DRAIN&&ahold_r)begin a_rd_valid=1;a_rd_address=ahold_address_r;end
  if(state_r==ERROR_DRAIN&&bhold_r)begin b_rd_valid=1;b_rd_address=bhold_address_r;end
 end
 always_comb begin
  reduce_fire_w=state_r==REDUCE&&src_count_w>0;
  reduce_max_w=0;reduce_bad_w=0;
  for(integer j=0;j<4;j=j+1)if(state_r==REDUCE&&(mode_r!=4||selected_p_w[j]))begin
   if(src_head_w[(integer'(src_sub_r)*4+j)*16+7+:8]==8'hff)reduce_bad_w=1;
   if(mode_r!=4||!src_head_w[(integer'(src_sub_r)*4+j)*16+15])begin
    if(src_head_w[(integer'(src_sub_r)*4+j)*16+:15]>reduce_max_w[14:0])reduce_max_w={1'b0,src_head_w[(integer'(src_sub_r)*4+j)*16+:15]};
   end
  end
  table_pop_w=table_count_w>0&&(state_r==STATIC_LOAD||state_r==ERROR_DRAIN);
  src_pop_w=src_count_w>0&&(
   reduce_fire_w&&src_sub_r==1 || state_r==QUANT_STREAM&&q_sv&&q_sr&&src_sub_r==1 ||
   state_r==DQ_STREAM&&d_sv&&d_sr&&src_sub_r==3 || state_r==DQ_SCALE ||
   state_r==ERROR_DRAIN&&!qhold_r&&!dhold_r);
 end
 always_comb begin
  q_sv=0;q_bf16=0;q_scale=0;q_mask=0;q_tag=0;q_unsigned=opcode_r==13&&mode_r==4;
  if(state_r==SCALE_GEN&&scale_issue_r<scale_count_r)begin
   q_sv=1;q_tag={64'd0,32'(scale_issue_r)};q_unsigned=0;
   for(integer j=0;j<4;j=j+1)if(scale_issue_r+j<scale_count_r)begin q_bf16[j*16+:16]=max_r[scale_issue_r+j];q_scale[j*32+:32]=32'h42fe0000;q_mask[j]=1;end
  end else if(state_r==QUANT_STREAM&&src_count_w>0)begin
   q_sv=1;q_tag={64'd0,32'(elem_r)};
   for(integer j=0;j<4;j=j+1)begin
    q_bf16[j*16+:16]=src_head_w[(integer'(src_sub_r)*4+j)*16+:16];q_scale[j*32+:32]=scales_r[group_w];
    q_mask[j]=mode_r!=4||selected_p_w[j];
   end
  end
  if(state_r==ERROR_DRAIN&&qhold_r)begin q_sv=1;q_bf16=qhold_bf16_r;q_scale=qhold_scale_r;q_unsigned=qhold_unsigned_r;q_mask=qhold_mask_r;q_tag=qhold_tag_r;end
  d_sv=state_r==DQ_STREAM&&src_count_w>0;d_int8=src_head_w[integer'(src_sub_r)*32+:32];
  d_scale={4{dq_scale_r}};d_mask=4'hf;d_tag={64'd0,32'(dq_row_r*1152+elem_r*2)};
  if(state_r==ERROR_DRAIN&&dhold_r)begin d_sv=1;d_int8=dhold_int8_r;d_scale=dhold_scale_r;d_mask=dhold_mask_r;d_tag=dhold_tag_r;end
 end
 w8a8_quant_lane4 quantization(.clk,.resetn,.s_valid(q_sv),.s_ready(q_sr),.s_bf16(q_bf16),.s_scale(q_scale),.s_unsigned(q_unsigned),.s_mask(q_mask),.s_tag(q_tag),.m_valid(q_mv),.m_ready(q_mr),.m_int8(q_int8),.m_mask(q_mmask),.m_tag(q_mtag),.m_error(q_error),.m_quotient(q_quotient));
 w8a8_dequant_lane4 dequantization(.clk,.resetn,.s_valid(d_sv),.s_ready(d_sr),.s_int8(d_int8),.s_scale(d_scale),.s_mask(d_mask),.s_tag(d_tag),.m_valid(d_mv),.m_ready(d_mr),.m_bf16(d_bf16),.m_mask(d_mmask),.m_tag(d_mtag),.m_error(d_error));
 assign bundle_fire_w=reduce_fire_w||(state_r==QUANT_STREAM&&q_sv&&q_sr)||(state_r==DQ_STREAM&&d_sv&&d_sr);
 assign c_wr_valid=write_valid_r[write_read_r];assign c_wr_address=write_address_r[write_read_r];
 assign c_wr_data=write_data_r[write_read_r];assign c_wr_strb=write_strb_r[write_read_r];
 assign pack_space_w=!write_valid_r[write_fill_r]||(c_wr_valid&&c_wr_ready&&write_read_r==write_fill_r);
 assign q_mr=error_r!=0||(|q_error)||state_r==SCALE_GEN||state_r==SCALE_DRAIN||pack_space_w;
 assign d_mr=error_r!=0||(|d_error)||pack_space_w;
 always_comb begin
  numeric_fault_w=error_r==0&&((q_mv&&q_mr&&(|q_error))||(d_mv&&d_mr&&(|d_error))||reduce_fire_w&&reduce_bad_w);
  append_w=error_r==0&&((q_mv&&q_mr&&!(|q_error)&&(state_r==QUANT_STREAM||state_r==QUANT_DRAIN))||d_mv&&d_mr&&!(|d_error));
  append_data_w=d_mv?d_bf16:{32'd0,q_int8};append_offset_w=d_mv?d_mtag[31:0]:q_mtag[31:0];append_bytes_w=d_mv?8:4;
  for(integer j=0;j<4;j=j+1)if(!d_mv&&!q_mmask[j])append_data_w[j*8+:8]=0;
  metadata_w=state_r==SCALE_WRITE&&scale_write_r<scale_words_r&&pack_space_w;
  metadata_data_w=0;
  for(integer j=0;j<4;j=j+1)if(scale_write_r*4+j<scale_count_r)metadata_data_w[j*32+:32]=scales_r[scale_write_r*4+j];
  drain_w=src_credit_w==0&&table_credit_w==0&&q_pending_r==0&&d_pending_r==0&&!qhold_r&&!dhold_r&&!ahold_r&&!bhold_r&&write_valid_r==0&&pack_bytes_r==0;
 end
 always_ff @(posedge clk) begin
  if(!resetn)begin
   state_r<=IDLE;opcode_r<=0;payload_r<=0;banks_r<=0;txn_r<=0;gens_r<=0;desc_gens_r<=0;
   profiles_r<=0;layers_r<=0;owners_r<=0;rows_desc_r<=0;cols_desc_r<=0;positions_r<=0;
   present_r<=0;data_ready_r<=0;scale_ready_r<=0;busy_r<=0;static_valid_r<=0;embedding_lanes_r<=0;embedding_valid_r<=0;
   mode_r<=0;error_r<=0;begun_r<=0;rows_r<=0;mstart_r<=0;k_r<=0;length_r<=0;query_r<=0;layer_r<=0;groups_r<=0;width_r<=0;padded_r<=0;
   scale_count_r<=0;scale_words_r<=0;scale_base_r<=0;source_words_r<=0;source_base_r<=0;
   src_issued_r<=0;src_returned_r<=0;src_consumed_r<=0;table_issued_r<=0;table_returned_r<=0;table_consumed_r<=0;
   src_sub_r<=0;elem_r<=0;relative_row_r<=0;row_column_r<=0;head_index_r<=0;head_feature_r<=0;scale_issue_r<=0;scale_retired_r<=0;scale_write_r<=0;dq_row_r<=0;dq_scale_r<=0;
   q_pending_r<=0;d_pending_r<=0;qhold_r<=0;dhold_r<=0;ahold_r<=0;bhold_r<=0;
   write_valid_r<=0;write_read_r<=0;write_fill_r<=0;pack_bytes_r<=0;
  end else begin
   if(a_rd_valid&&a_rd_ready)src_issued_r<=src_issued_r+1;
   if(b_rd_valid&&b_rd_ready)table_issued_r<=table_issued_r+1;
   if(a_rd_resp_valid)begin src_fifo_r[(src_returned_r&3)]<=a_rd_data;src_returned_r<=src_returned_r+1;end
   if(b_rd_resp_valid)begin table_fifo_r[(table_returned_r&3)]<=b_rd_data;table_returned_r<=table_returned_r+1;end
   if(src_pop_w)begin src_consumed_r<=src_consumed_r+1;src_sub_r<=0;end
   if(table_pop_w)table_consumed_r<=table_consumed_r+1;
   if(a_rd_valid)begin ahold_r<=!a_rd_ready;if(!a_rd_ready)ahold_address_r<=a_rd_address;end
   if(b_rd_valid)begin bhold_r<=!b_rd_ready;if(!b_rd_ready)bhold_address_r<=b_rd_address;end
   if(q_sv)begin
    qhold_r<=!q_sr;
    if(!q_sr)begin qhold_bf16_r<=q_bf16;qhold_scale_r<=q_scale;qhold_unsigned_r<=q_unsigned;qhold_mask_r<=q_mask;qhold_tag_r<=q_tag;end
   end
   if(d_sv)begin
    dhold_r<=!d_sr;
    if(!d_sr)begin dhold_int8_r<=d_int8;dhold_scale_r<=d_scale;dhold_mask_r<=d_mask;dhold_tag_r<=d_tag;end
   end
   case({q_sv&&q_sr,q_mv&&q_mr})2'b10:q_pending_r<=q_pending_r+1;2'b01:q_pending_r<=q_pending_r-1;default:;endcase
   case({d_sv&&d_sr,d_mv&&d_mr})2'b10:d_pending_r<=d_pending_r+1;2'b01:d_pending_r<=d_pending_r-1;default:;endcase
   if(bundle_fire_w)begin
    if(row_column_r+14'd4==14'(width_r))begin row_column_r<=0;relative_row_r<=relative_row_r+6'd1;head_index_r<=0;head_feature_r<=0;end
    else begin
     row_column_r<=row_column_r+14'd4;
     if(head_feature_r+11'd4==(mode_r==4?11'(padded_r):11'd64))begin head_feature_r<=0;head_index_r<=head_index_r+4'd1;end
     else head_feature_r<=head_feature_r+11'd4;
    end
   end
   if(reduce_fire_w)begin
    if(reduce_max_w>max_r[group_w])max_r[group_w]<=reduce_max_w;
    elem_r<=elem_r+4;if(!src_pop_w)src_sub_r<=src_sub_r+1;
   end
   if(state_r==QUANT_STREAM&&q_sv&&q_sr || state_r==DQ_STREAM&&d_sv&&d_sr)begin
    elem_r<=elem_r+4;if(!src_pop_w)src_sub_r<=src_sub_r+1;
   end
   if(state_r==STATIC_LOAD&&table_pop_w)for(integer j=0;j<4;j=j+1)
    if(table_consumed_r*4+j<scale_count_r)scales_r[table_consumed_r*4+j]<=table_head_w[j*32+:32];
   if(state_r==DQ_SCALE&&src_pop_w)dq_scale_r<=src_head_w[integer'(embedding_lanes_r[dq_row_r*2+:2])*32+:32];
   if(state_r==SCALE_GEN&&q_sv&&q_sr)scale_issue_r<=scale_issue_r+4;
   if((state_r==SCALE_GEN||state_r==SCALE_DRAIN)&&q_mv&&q_mr)begin
    scale_retired_r<=scale_retired_r+4;
    for(integer j=0;j<4;j=j+1)if(q_mmask[j])scales_r[integer'(q_mtag[31:0])+j]<=max_r[integer'(q_mtag[31:0])+j]==0?32'h3f800000:q_quotient[j*32+:32];
   end
   if(c_wr_valid&&c_wr_ready)begin write_valid_r[write_read_r]<=0;write_read_r<=!write_read_r;end
   if(metadata_w)begin
    write_data_r[write_fill_r]<=metadata_data_w;write_address_r[write_fill_r]<=19'(scale_base_r/16+scale_write_r);
    write_strb_r[write_fill_r]<=16'hffff;write_valid_r[write_fill_r]<=1;write_fill_r<=!write_fill_r;scale_write_r<=scale_write_r+1;
   end
   if(append_w)begin
    if(pack_bytes_r==0)write_address_r[write_fill_r]<=19'(append_offset_w/16);
    for(integer j=0;j<8;j=j+1)if(j<append_bytes_w)write_data_r[write_fill_r][(pack_bytes_r+j)*8+:8]<=append_data_w[j*8+:8];
    write_strb_r[write_fill_r]<=16'((1<<(pack_bytes_r+append_bytes_w))-1);
    if(pack_bytes_r+append_bytes_w==16)begin write_valid_r[write_fill_r]<=1;write_fill_r<=!write_fill_r;pack_bytes_r<=0;end
    else pack_bytes_r<=pack_bytes_r+append_bytes_w;
   end
   if(state_r==ERROR_DRAIN&&pack_bytes_r>0&&pack_space_w)begin
    write_valid_r[write_fill_r]<=1;write_fill_r<=!write_fill_r;pack_bytes_r<=0;
   end
   case(state_r)
    IDLE:if(cmd_valid&&cmd_ready)begin
     opcode_r<=cmd_opcode;payload_r<=cmd_payload;banks_r<=cmd_bank_ids;txn_r<=cmd_transaction_id;gens_r<=cmd_generations;
     desc_gens_r<=cmd_desc_generations;profiles_r<=cmd_profiles;layers_r<=cmd_layers;owners_r<=cmd_desc_owner;
     rows_desc_r<=cmd_rows;cols_desc_r<=cmd_cols;positions_r<=cmd_positions;present_r<=cmd_desc_present;
     data_ready_r<=cmd_data_valid;scale_ready_r<=cmd_scale_valid;busy_r<=cmd_desc_busy;static_valid_r<=cmd_b7_static_valid;
     embedding_lanes_r<=cmd_embedding_lanes;embedding_valid_r<=cmd_embedding_lane_valid;
     mode_r<=cmd_payload[2:0];mstart_r<=integer'(cmd_payload[8:3]);rows_r<=integer'(cmd_payload[14:9]);k_r<=integer'(cmd_payload[25:15]);
     length_r<=integer'(cmd_payload[36:26]);query_r<=integer'(cmd_payload[46:37]);layer_r<=integer'(cmd_payload[51:47]);
     groups_r<=(integer'(cmd_payload[14:9])+15)/16;padded_r<=((integer'(cmd_payload[36:26])+15)/16)*16;
     width_r<=cmd_opcode==14?576:cmd_payload[2:0]==0?integer'(cmd_payload[25:15]):cmd_payload[2:0]==1?576:cmd_payload[2:0]==4?9*((integer'(cmd_payload[36:26])+15)/16)*16:192;
     error_r<=0;begun_r<=0;dq_row_r<=0;state_r<=CHECK;
     src_issued_r<=0;src_returned_r<=0;src_consumed_r<=0;table_issued_r<=0;table_returned_r<=0;table_consumed_r<=0;
     elem_r<=0;relative_row_r<=0;row_column_r<=0;head_index_r<=0;head_feature_r<=0;src_sub_r<=0;scale_issue_r<=0;scale_retired_r<=0;scale_write_r<=0;
     for(integer j=0;j<18;j=j+1)begin max_r[j]<=0;scales_r[j]<=0;end
    end
    CHECK:begin
     scale_count_r<=mode_r==0?groups_r:mode_r==1||mode_r==4?9*groups_r:mode_r==2?3:12;
     scale_words_r<=((mode_r==0?groups_r:mode_r==1||mode_r==4?9*groups_r:mode_r==2?3:12)+3)/4;
     scale_base_r<=mode_r==1?18432:static_mode_w?196608:294912;
     source_base_r<=mstart_r*width_r*2;source_words_r<=rows_r*width_r/8;
     if(descriptor_error_w!=0)begin error_r<=descriptor_error_w;state_r<=ERROR_DRAIN;end else state_r<=BEGIN_DST;
    end
    BEGIN_DST:if(dst_begin_valid&&dst_begin_ready)begin
     if(dst_begin_error_code!=0)begin error_r<=7;state_r<=ERROR_DRAIN;end
     else begin begun_r<=1;state_r<=opcode_r==14?DQ_SCALE:static_mode_w?STATIC_LOAD:REDUCE;end
    end
    STATIC_LOAD:if(table_consumed_r==(mode_r==2?1:3))state_r<=STATIC_VALIDATE;
    STATIC_VALIDATE:begin
     state_r<=SCALE_WRITE;
     for(integer j=0;j<18;j=j+1)if(j<scale_count_r&&!valid_scale(scales_r[j]))begin error_r<=5;state_r<=ERROR_DRAIN;end
    end
    REDUCE:if(src_consumed_r==source_words_r)begin
     src_issued_r<=0;src_returned_r<=0;src_consumed_r<=0;src_sub_r<=0;elem_r<=0;relative_row_r<=0;row_column_r<=0;head_index_r<=0;head_feature_r<=0;state_r<=SCALE_GEN;
    end
    SCALE_GEN:if(scale_issue_r>=scale_count_r)state_r<=SCALE_DRAIN;
    SCALE_DRAIN:if(q_pending_r==0&&scale_retired_r>=scale_count_r)state_r<=SCALE_WRITE;
    SCALE_WRITE:if(scale_write_r==scale_words_r)state_r<=SCALE_WRITE_DRAIN;
    SCALE_WRITE_DRAIN:if(write_valid_r==0)state_r<=QUANT_STREAM;
    QUANT_STREAM:if(src_consumed_r==source_words_r)state_r<=QUANT_DRAIN;
    QUANT_DRAIN:if(drain_w)state_r<=RESPONSE;
    DQ_SCALE:if(src_consumed_r==1)begin
     if(!valid_scale(dq_scale_r))begin error_r<=5;state_r<=ERROR_DRAIN;end
     else begin src_issued_r<=0;src_returned_r<=0;src_consumed_r<=0;src_sub_r<=0;elem_r<=0;relative_row_r<=0;row_column_r<=0;head_index_r<=0;head_feature_r<=0;source_base_r<=dq_row_r*576;source_words_r<=36;state_r<=DQ_STREAM;end
    end
    DQ_STREAM:if(src_consumed_r==source_words_r)state_r<=DQ_DRAIN;
    DQ_DRAIN:if(drain_w)begin
     if(dq_row_r+1==rows_r)state_r<=RESPONSE;
     else begin dq_row_r<=dq_row_r+1;src_issued_r<=0;src_returned_r<=0;src_consumed_r<=0;src_sub_r<=0;elem_r<=0;relative_row_r<=0;row_column_r<=0;head_index_r<=0;head_feature_r<=0;state_r<=DQ_SCALE;end
    end
    ERROR_DRAIN:if(drain_w)state_r<=INVALIDATE;
    INVALIDATE:if(dst_invalidate_valid&&dst_invalidate_ready)state_r<=RESPONSE;
    RESPONSE:if(resp_valid&&resp_ready)state_r<=IDLE;
    default:state_r<=IDLE;
   endcase
   if(numeric_fault_w)begin error_r<=5;state_r<=ERROR_DRAIN;end
  end
 end
endmodule
