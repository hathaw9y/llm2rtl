module smollm2_int8_gemm_executor(
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
 input logic [255:0] a_rd_data,
 input logic b_rd_ready,
 input logic b_rd_resp_valid,
 input logic [255:0] b_rd_data,
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
 // One command, three shared native bank roles, no autonomous DMA.
 typedef enum logic[4:0] {IDLE,CHECK,BEGIN_DST,LOAD_AS,LOAD_BS,VALID_S,
  LOAD_A,SCALE_REQ,SCALE_WAIT,SCALE_Q_REQ,SCALE_Q_WAIT,RUN,WAIT_DRAIN,
  NEXT_PANEL,ERROR_DRAIN,INVALIDATE,RESPONSE} state_t;
 state_t state_r;
 logic[3:0] opcode_r;logic[111:0]payload_r;logic[11:0]banks_r;
 logic[31:0]txn_r;logic[95:0]gens_r,descgens_r;
 logic[14:0]profiles_r,owners_r,layers_r;logic[32:0]rows_desc_r;
 logic[47:0]cols_desc_r;logic[29:0]positions_r;
 logic[2:0]present_r,data_valid_r,scale_valid_r,busy_r;
 logic[7:0]error_r;logic begun_r;
 integer rows_r,k_r,n_r,ntotal_r,nstart_r,mstart_r,query_r,length_r,padded_r;
 integer groups_r,logical_rows_r,astride_r,kv_r,npanel_r;
 integer ai_r,ar_r,bi_r,br_r;integer acredits_w,bcredits_w;
 integer a_scale_count_r,b_scale_count_r;
 logic[31:0] a_scales_r[0:17],b_scales_r[0:11],combined_r[0:5];
 // Two independently addressed128-bit half planes yield one256-bit staged word.
 (* ram_style="block" *) logic[127:0] a_low_r[0:3071],a_high_r[0:3071];
 logic[255:0] b_panels_r[0:1][0:15];logic[1:0] panel_ready_r;
 integer fill_k_r,fill_slot_r,fill_i_r,fill_recv_r,fill_requests_w;
 logic filling_r;integer active_slot_r,active_k_r,issue_row_r,issue_half_r;
 integer scale_i_r,scale_count_w;
 logic[31:0] scale_ab_r;logic[7:0] descriptor_error_w;
 logic mul_sv,mul_sr,mul_mv,mul_mnf;logic[31:0]mul_a,mul_b,mul_result;
 logic[95:0]mul_tag;
 logic core_sv,core_sr,core_mv,core_mr;logic[127:0]core_a;logic[2047:0]core_b;
 logic[6:0]core_row;logic core_first,core_last;logic[4:0]core_nv,core_mnv;
 logic[95:0]core_tag,core_mtag;logic[31:0]core_scale,core_mscale;
 logic[511:0]core_sums;
 (* ram_style="block" *) logic[639:0] result_fifo_r[0:127];
 logic[6:0] fifo_wr_r,fifo_rd_r;integer fifo_count_r,core_pending_r,epi_pending_r;
 integer bundle_r;
 logic epi_sv,epi_sr,epi_mv,epi_mr,epi_error;
 logic[127:0]epi_sums,epi_scales;logic[3:0]epi_mask,epi_mmask;
 logic[95:0]epi_tag,epi_mtag;logic[63:0]epi_bf16;
 logic[639:0]fifo_head_w;logic fifo_head_valid_r;
 logic issue_valid_w,stage_ready_w,stage_capture_w,stage_valid_r;
 logic[255:0]a_stage_word_r;logic stage_half_r;logic[2047:0]issue_b_w;
 logic[6:0]issue_row_w;logic issue_first_w,issue_last_w;logic[4:0]issue_nv_w;
 logic[95:0]issue_tag_w;logic[31:0]issue_scale_w;logic fifo_pop_w,fifo_push_w;
 integer scale_index_w,output_base_w,nvalid_w,scale_a_index_w,scale_b_index_w;
 integer a_src_w,a_requests_w,a_scale_base_w,b_scale_base_w;
 integer b_src_w,b_channel_w,b_half_w,b_token_w;
 logic drain_w;
 logic ahold_r,bhold_r;logic[18:0]ahold_addr_r,bhold_addr_r;logic ahold_wide_r,bhold_wide_r;integer core_quiet_r;
 function automatic logic valid_scale(input logic[31:0]v);
  valid_scale=!v[31] && v[30:0]!=0 && v[30:23]!=8'hff;
 endfunction
 function automatic integer min_i(input integer x,y);min_i=x<y?x:y;endfunction
 assign cmd_ready=resetn&&state_r==IDLE;
 assign resp_valid=state_r==RESPONSE;
 assign resp_transaction_id=txn_r;assign resp_bank_ids=banks_r;
 assign resp_generations=gens_r;assign resp_used_bank_mask=3'b111;
 assign resp_used_bank_count=2'd3;assign resp_error_code=error_r;
 assign a_role=opcode_r==3?5'd3:opcode_r==6?5'd11:5'd15;
 assign b_role=opcode_r==3?5'd4:opcode_r==6?5'd12:5'd16;
 assign c_role=opcode_r==3?5'd5:opcode_r==6?5'd13:5'd17;
 assign a_rd_bank=banks_r[3:0];assign b_rd_bank=banks_r[7:4];assign c_wr_bank=banks_r[11:8];
 assign dst_begin_valid=state_r==BEGIN_DST;
 assign dst_begin_bank=banks_r[11:8];assign dst_begin_accepted_generation=gens_r[95:64];
 assign dst_begin_generation=gens_r[95:64]+32'd1;
 assign dst_begin_profile=opcode_r==6?5'd16:5'd19;
 assign dst_begin_rows=11'(rows_r);assign dst_begin_cols=16'(opcode_r==6?length_r:576);
 assign dst_begin_position=10'(opcode_r==6?query_r:0);assign dst_begin_layer=5'd0;
 assign dst_invalidate_valid=state_r==INVALIDATE;
 assign dst_invalidate_bank=banks_r[11:8];
 assign dst_invalidate_generation=gens_r[95:64]+(begun_r?32'd1:32'd0);
 always_comb begin
  descriptor_error_w=0;
  if(opcode_r!=3 && opcode_r!=6 && opcode_r!=8) descriptor_error_w=1;
  else if ((opcode_r==3 && payload_r[111:63]!=0) || (opcode_r!=3&&payload_r[111:27]!=0))descriptor_error_w=1;
  else if(banks_r[3:0]==banks_r[7:4]||banks_r[3:0]==banks_r[11:8]||banks_r[7:4]==banks_r[11:8])descriptor_error_w=2;
  else if ((opcode_r==3 && (banks_r[3:0]!=13 || (banks_r[7:4]!=3&&banks_r[7:4]!=15) ||
   !(banks_r[11:8]==1||banks_r[11:8]==4||banks_r[11:8]==5||banks_r[11:8]==6||banks_r[11:8]==8||banks_r[11:8]==9||banks_r[11:8]==12))) ||
   (opcode_r==6&&banks_r!=12'ha8e)||(opcode_r==8&&banks_r!=12'hb9d))descriptor_error_w=2;
  else if(present_r[1:0]!=2'b11||profiles_r[4:0]!=(opcode_r==3?21:opcode_r==6?23:22)||
   profiles_r[9:5]!=(opcode_r==3?4:opcode_r==6?12:14))descriptor_error_w=2;
  else if (gens_r!=descgens_r || busy_r!=3'b111 || owners_r[4:0]!=a_role || owners_r[9:5]!=b_role || owners_r[14:10]!=c_role)descriptor_error_w=7;
  else if(gens_r[31:0]==0||gens_r[63:32]==0)descriptor_error_w=7;
  else if(data_valid_r[1:0]!=2'b11||scale_valid_r[1:0]!=2'b11)descriptor_error_w=4;
  else if(rows_r<1||rows_r>32||k_r<1||k_r>1536||n_r<1||n_r>1024)descriptor_error_w=3;
  else if(opcode_r==3 && (integer'(rows_desc_r[10:0])<1 || integer'(rows_desc_r[10:0])>32 || positions_r!=0 || layers_r!=0))descriptor_error_w=3;
  else if(opcode_r!=3 && (positions_r[19:10]!=0 || (opcode_r==6&&positions_r[9:0]!=0) || layers_r[4:0]!=0 || integer'(layers_r[9:5])>=30))descriptor_error_w=3;
  else if(opcode_r==3 && (k_r!=576&&k_r!=1536 || n_r>192 || nstart_r%64!=0 || nstart_r+n_r>ntotal_r ||
    mstart_r+rows_r>integer'(rows_desc_r[10:0]) || integer'(cols_desc_r[15:0])!=k_r ||
    integer'(rows_desc_r[21:11])!=n_r || integer'(cols_desc_r[31:16])!=k_r ||
    !present_r[2] || integer'(rows_desc_r[32:22])!=rows_r ||integer'(cols_desc_r[47:32])!=ntotal_r))descriptor_error_w=3;
  else if(opcode_r==3 && (profiles_r[14:10]!=(banks_r[11:8]==1?2:banks_r[11:8]==4?7:banks_r[11:8]==5?8:banks_r[11:8]==6?10:banks_r[11:8]==8?13:banks_r[11:8]==9?15:20)))descriptor_error_w=2;
  else if(opcode_r==3 && banks_r[11:8]==12 && rows_r!=1)descriptor_error_w=3;
  else if(opcode_r==3 && (ntotal_r!=(banks_r[11:8]==5||banks_r[11:8]==6?192:banks_r[11:8]==8||banks_r[11:8]==9?1536:banks_r[11:8]==12?49152:576)))descriptor_error_w=3;
  else if(opcode_r!=3 && (length_r<1||length_r>1024||query_r+rows_r>length_r || integer'(rows_desc_r[10:0])!=rows_r ||
    integer'(rows_desc_r[21:11])!=length_r ||integer'(cols_desc_r[31:16])!=192 ||
    integer'(cols_desc_r[15:0])!=(opcode_r==6?576:length_r)|| (opcode_r==8&&integer'(positions_r[9:0])!=query_r)))descriptor_error_w=3;
  else if(opcode_r!=3&&gens_r[95:64]==32'hffffffff)descriptor_error_w=7;
 end
 // The native response has no ready: every returned beat is processed immediately.
 // Credits count acceptance minus processing, never arrival without processing.
 always_comb begin
  acredits_w=ai_r-ar_r; bcredits_w=bi_r-br_r;
  a_scale_base_w=opcode_r==6?18432:294912;b_scale_base_w=opcode_r==3?294912:196608;
  a_requests_w=logical_rows_r*astride_r;
  if(opcode_r==3)a_src_w=(mstart_r+ai_r/astride_r)*k_r;
  else if(opcode_r==6)a_src_w=(ai_r/astride_r%(rows_r>0?rows_r:1))*576+(kv_r*3+ai_r/astride_r/(rows_r>0?rows_r:1))*64;
  else a_src_w=((ai_r/astride_r%(rows_r>0?rows_r:1))*9+kv_r*3+ai_r/astride_r/(rows_r>0?rows_r:1))*padded_r;
  a_src_w=(a_src_w&~31)+(ai_r%astride_r)*32;
  a_rd_valid=(state_r==LOAD_AS && ai_r<(a_scale_count_r+7)/8 || state_r==LOAD_A&&ai_r<a_requests_w) && acredits_w<4;
  a_rd_wide=1;
  a_rd_address=19'((state_r==LOAD_AS?a_scale_base_w+ai_r*32:a_src_w&~31)/16);
  b_rd_valid=state_r==LOAD_BS && bi_r<(b_scale_count_r+(opcode_r==3?7:3))/(opcode_r==3?8:4) && bcredits_w<4;
  b_rd_wide=state_r==LOAD_BS?(opcode_r==3):opcode_r==3;
  b_rd_address=19'((b_scale_base_w+bi_r*(opcode_r==3?32:16))/16);
  fill_requests_w=opcode_r==3?16:32;
  b_channel_w=opcode_r==3?fill_i_r:fill_i_r/2;
  b_half_w=opcode_r==3?0:fill_i_r%2;
  b_token_w=fill_k_r+fill_i_r;
  if(state_r==RUN && filling_r && fill_i_r<fill_requests_w && bcredits_w<4)begin
   b_rd_valid=1;
   if(opcode_r==3)b_src_w=(npanel_r+b_channel_w)*k_r+fill_k_r;
   else if(opcode_r==6)b_src_w=(npanel_r+b_channel_w)*192+kv_r*64+fill_k_r+b_half_w*16;
   else b_src_w=b_token_w*192+kv_r*64+npanel_r;
   b_rd_address=19'(b_src_w/16);
   if((opcode_r!=8&&npanel_r+b_channel_w>=(opcode_r==6?length_r:n_r))||(opcode_r==8&&b_token_w>=k_r))b_rd_address=0;
  end else b_src_w=0;
  if(state_r==ERROR_DRAIN&&ahold_r)begin a_rd_valid=1;a_rd_address=ahold_addr_r;a_rd_wide=ahold_wide_r;end
  if(state_r==ERROR_DRAIN&&bhold_r)begin b_rd_valid=1;b_rd_address=bhold_addr_r;b_rd_wide=bhold_wide_r;end
 end
 // Cached scales combine once per N16 panel and row/head scale group.
 always_comb begin
  scale_count_w=opcode_r==3?groups_r:3*groups_r;
  scale_a_index_w=opcode_r==3?(mstart_r/16+scale_i_r):(kv_r*3*groups_r+scale_i_r);
  scale_b_index_w=opcode_r==3?npanel_r/16:opcode_r==6?kv_r:kv_r*4+npanel_r/16;
  mul_sv=state_r==SCALE_REQ||state_r==SCALE_Q_REQ;
  mul_a=state_r==SCALE_Q_REQ?scale_ab_r:a_scales_r[scale_a_index_w];
  mul_b=state_r==SCALE_Q_REQ?32'h3e000000:b_scales_r[scale_b_index_w];
 end
 w8a8_fp32_mul scale_multiplier(.clk,.resetn,.s_valid(mul_sv),.s_ready(mul_sr),.s_a(mul_a),.s_b(mul_b),.s_tag(96'd0),.m_valid(mul_mv),.m_ready(1'b1),.m_result(mul_result),.m_tag(mul_tag),.m_nonfinite(mul_mnf));
 always_comb begin
  issue_valid_w=state_r==RUN && panel_ready_r[active_slot_r] && issue_row_r<logical_rows_r;
  issue_row_w=7'(issue_row_r);issue_first_w=active_k_r==0&&issue_half_r==0;
  issue_last_w=active_k_r+issue_half_r*16+16>=k_r;
  for(integer n=0;n<16;n=n+1) issue_b_w[n*128+:128]=b_panels_r[active_slot_r][n][issue_half_r*128+:128];
  issue_nv_w=5'(min_i(16,n_r-npanel_r));
  scale_index_w=opcode_r==3?(mstart_r%16+issue_row_r)/16:(issue_row_r/(rows_r>0?rows_r:1))*groups_r+(issue_row_r%(rows_r>0?rows_r:1))/16;
  issue_scale_w=combined_r[scale_index_w];
  if(opcode_r==3)output_base_w=issue_row_r*ntotal_r+nstart_r+npanel_r;
  else if(opcode_r==6)output_base_w=((issue_row_r%(rows_r>0?rows_r:1))*9+kv_r*3+issue_row_r/(rows_r>0?rows_r:1))*padded_r+npanel_r;
  else output_base_w=(issue_row_r%(rows_r>0?rows_r:1))*576+(kv_r*3+issue_row_r/(rows_r>0?rows_r:1))*64+npanel_r;
  issue_tag_w={59'd0,issue_nv_w,32'(output_base_w)};
 end
 assign core_sv=stage_valid_r;
 assign core_a=stage_half_r?a_stage_word_r[255:128]:a_stage_word_r[127:0];
 assign stage_ready_w=!stage_valid_r||core_sr;
 assign stage_capture_w=issue_valid_w&&stage_ready_w;
 always_ff @(posedge clk)begin
  if(!resetn)begin stage_valid_r<=0;stage_half_r<=0;core_b<=0;core_row<=0;core_first<=0;core_last<=0;core_nv<=0;core_tag<=0;core_scale<=0;end
  else if(stage_ready_w)begin
   stage_valid_r<=issue_valid_w;
   if(issue_valid_w)begin
    a_stage_word_r<={a_high_r[issue_row_r*astride_r+active_k_r/32],a_low_r[issue_row_r*astride_r+active_k_r/32]};
    stage_half_r<=1'(issue_half_r);core_b<=issue_b_w;core_row<=issue_row_w;
    core_first<=issue_first_w;core_last<=issue_last_w;core_nv<=issue_nv_w;core_tag<=issue_tag_w;core_scale<=issue_scale_w;
   end
  end
 end

 int8_dot_core dots(.clk,.resetn,.step_valid(core_sv),.step_ready(core_sr),.step_a(core_a),.step_b(core_b),.step_row(core_row),.step_first_k(core_first),.step_last_k(core_last),.step_n_valid(core_nv),.step_tag(core_tag),.step_scale(core_scale),.result_valid(core_mv),.result_ready(core_mr),.result_sums(core_sums),.result_n_valid(core_mnv),.result_tag(core_mtag),.result_scale(core_mscale));
 assign core_mr=error_r!=0||fifo_count_r<128;
 assign fifo_push_w=core_mv&&core_mr&&error_r==0;
 // Synchronous RAM output register; count includes the held output vector.
 always_ff @(posedge clk)begin
  if(!resetn)fifo_head_valid_r<=0;
  else if(error_r!=0)fifo_head_valid_r<=0;
  else if(!fifo_head_valid_r||fifo_pop_w)begin
   fifo_head_valid_r<=fifo_count_r>(fifo_pop_w?1:0);
   if(fifo_count_r>(fifo_pop_w?1:0))fifo_head_w<=result_fifo_r[7'(fifo_rd_r+(fifo_pop_w?7'd1:7'd0))];
  end
 end
 always_comb begin
  epi_sv=fifo_head_valid_r&&error_r==0;
  nvalid_w=integer'(fifo_head_w[548:544]);
  epi_tag={64'd0,32'(integer'(fifo_head_w[543:512])+bundle_r*4)};
  epi_mask=0;
  for(integer j=0;j<4;j=j+1)begin
   epi_sums[j*32+:32]=fifo_head_w[(bundle_r*4+j)*32+:32];
   epi_scales[j*32+:32]=fifo_head_w[639:608];
   if(bundle_r*4+j<nvalid_w)epi_mask[j]=1;
   if(opcode_r==6 && ((integer'(epi_tag[31:0])+j)%(padded_r>0?padded_r:1)>query_r+(integer'(epi_tag[31:0])+j)/(9*(padded_r>0?padded_r:1))))epi_sums[j*32+:32]=0;
  end
 end
 // FIFO packed as scale32,tag96,sums512. tag N count is bits548:544.
 // (The assignments below intentionally use exact packet bit slices.)
 assign fifo_pop_w=(epi_sv&&epi_sr&&bundle_r==3)||(error_r!=0&&fifo_count_r!=0);
 fp32_bf16_epilogue output_conversion(.clk,.resetn,.in_valid(epi_sv),.in_ready(epi_sr),.in_sums(epi_sums),.in_scales(epi_scales),.in_mask(epi_mask),.in_tag(epi_tag),.out_valid(epi_mv),.out_ready(epi_mr),.out_bf16(epi_bf16),.out_mask(epi_mmask),.out_tag(epi_mtag),.out_error(epi_error));
 always_comb begin
  c_wr_valid=epi_mv&&error_r==0&&!epi_error;
  c_wr_address=19'(epi_mtag[31:0]>>3);
  c_wr_data=0;c_wr_strb=0;
  for(integer j=0;j<4;j=j+1)begin
   c_wr_data[(integer'(epi_mtag[2])*4+j)*16+:16]=epi_bf16[j*16+:16];
   c_wr_strb[(integer'(epi_mtag[2])*4+j)*2+:2]={2{epi_mmask[j]}};
  end
  epi_mr=error_r!=0||epi_error||c_wr_ready;
  drain_w=!stage_valid_r&&core_quiet_r==0&&!ahold_r&&!bhold_r&&acredits_w==0&&bcredits_w==0&&core_pending_r==0&&fifo_count_r==0&&epi_pending_r==0;
 end
 integer response_source_w,response_row_w,response_chunk_w,response_dest_w;
 integer response_channel_w,response_half_w,response_token_w;
 logic[255:0]a_masked_w;logic[255:0]b_masked_w;
 logic operand_bad_w;
 always_comb begin
  response_row_w=ar_r/astride_r;response_chunk_w=ar_r%astride_r;
  response_dest_w=response_row_w*astride_r+response_chunk_w;
  if(opcode_r==3)response_source_w=(mstart_r+response_row_w)*k_r;
  else if(opcode_r==6)response_source_w=(response_row_w%(rows_r>0?rows_r:1))*576+(kv_r*3+response_row_w/(rows_r>0?rows_r:1))*64;
  else response_source_w=((response_row_w%(rows_r>0?rows_r:1))*9+kv_r*3+response_row_w/(rows_r>0?rows_r:1))*padded_r;
  a_masked_w=0;operand_bad_w=0;
  for(integer j=0;j<32;j=j+1)if(response_chunk_w*32+j-response_source_w%32>=0 && response_chunk_w*32+j-response_source_w%32<k_r)begin
   a_masked_w[j*8+:8]=a_rd_data[j*8+:8];
   if(a_rd_resp_valid&&state_r==LOAD_A && (a_rd_data[j*8+:8]==8'h80 || opcode_r==8&&a_rd_data[j*8+7]))operand_bad_w=1;
   if(opcode_r==8&&response_chunk_w*32+j-response_source_w%32>query_r+response_row_w%(rows_r>0?rows_r:1))a_masked_w[j*8+:8]=0;
  end
  response_channel_w=opcode_r==3?fill_recv_r:fill_recv_r/2;
  response_half_w=opcode_r==3?0:fill_recv_r%2;
  response_token_w=fill_k_r+fill_recv_r;
  b_masked_w=0;
  for(integer j=0;j<32;j=j+1)begin
   if(opcode_r==3 && npanel_r+response_channel_w<n_r && fill_k_r+j<k_r)begin
    b_masked_w[j*8+:8]=b_rd_data[j*8+:8];
    if(b_rd_resp_valid&&state_r==RUN&&b_rd_data[j*8+:8]==8'h80)operand_bad_w=1;
   end
   else if(opcode_r==6&&j<16 && npanel_r+response_channel_w<length_r && fill_k_r+response_half_w*16+j<k_r)begin
    b_masked_w[j*8+:8]=b_rd_data[j*8+:8];
    if(b_rd_resp_valid&&state_r==RUN&&b_rd_data[j*8+:8]==8'h80)operand_bad_w=1;
   end
   else if(opcode_r==8&&j<16&&response_token_w<k_r)begin
    b_masked_w[j*8+:8]=b_rd_data[j*8+:8];
    if(b_rd_resp_valid&&state_r==RUN&&b_rd_data[j*8+:8]==8'h80)operand_bad_w=1;
   end
  end
 end
 always_ff @(posedge clk)begin
  if(!resetn)begin
   ahold_r<=0;bhold_r<=0;ahold_addr_r<=0;bhold_addr_r<=0;ahold_wide_r<=0;bhold_wide_r<=0;core_quiet_r<=0;
   state_r<=IDLE;opcode_r<=3;payload_r<=0;banks_r<=0;txn_r<=0;gens_r<=0;
   profiles_r<=0;owners_r<=0;layers_r<=0;rows_desc_r<=0;cols_desc_r<=0;positions_r<=0;
   present_r<=0;data_valid_r<=0;scale_valid_r<=0;busy_r<=0;descgens_r<=0;
   error_r<=0;begun_r<=0;rows_r<=1;k_r<=1;n_r<=1;ntotal_r<=1;nstart_r<=0;mstart_r<=0;
   query_r<=0;length_r<=1;padded_r<=16;groups_r<=1;logical_rows_r<=1;astride_r<=1;
   kv_r<=0;npanel_r<=0;ai_r<=0;ar_r<=0;bi_r<=0;br_r<=0;
   a_scale_count_r<=1;b_scale_count_r<=1;
   panel_ready_r<=0;fill_k_r<=0;fill_slot_r<=0;fill_i_r<=0;fill_recv_r<=0;filling_r<=0;
   active_slot_r<=0;active_k_r<=0;issue_row_r<=0;issue_half_r<=0;
   scale_i_r<=0;scale_ab_r<=0;fifo_wr_r<=0;fifo_rd_r<=0;fifo_count_r<=0;
   core_pending_r<=0;epi_pending_r<=0;bundle_r<=0;
  end else begin
   ahold_r<=a_rd_valid&&!a_rd_ready;bhold_r<=b_rd_valid&&!b_rd_ready;
   if(a_rd_valid&&!a_rd_ready)begin ahold_addr_r<=a_rd_address;ahold_wide_r<=a_rd_wide;end
   if(b_rd_valid&&!b_rd_ready)begin bhold_addr_r<=b_rd_address;bhold_wide_r<=b_rd_wide;end
   if(core_sv&&core_sr)core_quiet_r<=6;else if(core_sr&&core_quiet_r>0)core_quiet_r<=core_quiet_r-1;
   if(a_rd_valid&&a_rd_ready)ai_r<=ai_r+1;
   if(b_rd_valid&&b_rd_ready)begin bi_r<=bi_r+1;if(state_r==RUN)fill_i_r<=fill_i_r+1;end
   if(a_rd_resp_valid)ar_r<=ar_r+1;
   if(b_rd_resp_valid)br_r<=br_r+1;
   // Unconditional response processing protects credit reservations through stalls.
   if(a_rd_resp_valid&&state_r==LOAD_AS)
    for(integer j=0;j<8;j=j+1)if(ar_r*8+j<a_scale_count_r)a_scales_r[ar_r*8+j]<=a_rd_data[j*32+:32];
   if(b_rd_resp_valid&&state_r==LOAD_BS)
    for(integer j=0;j<8;j=j+1)if(j<(opcode_r==3?8:4)&&br_r*(opcode_r==3?8:4)+j<b_scale_count_r)
     b_scales_r[br_r*(opcode_r==3?8:4)+j]<=b_rd_data[j*32+:32];
   if(a_rd_resp_valid&&state_r==LOAD_A)begin
    if(response_source_w%32==0)begin
     a_low_r[response_dest_w]<=a_masked_w[127:0];a_high_r[response_dest_w]<=a_masked_w[255:128];
    end else begin
     a_low_r[response_dest_w]<=a_masked_w[255:128];
     if(response_chunk_w>0)a_high_r[response_dest_w-1]<=a_masked_w[127:0];
     // Odd sixteen-byte source alignment occurs only with an odd padded K16 count;
     // the unused high half of the final K32 word is never issued to the core.
    end
   end
   if(b_rd_resp_valid&&state_r==RUN&&filling_r)begin
    fill_recv_r<=fill_recv_r+1;
    if(opcode_r==3)b_panels_r[fill_slot_r][response_channel_w]<=b_masked_w;
    else if(opcode_r==6)b_panels_r[fill_slot_r][response_channel_w][response_half_w*128+:128]<=b_masked_w[127:0];
    else for(integer j=0;j<16;j=j+1)b_panels_r[fill_slot_r][j][fill_recv_r*8+:8]<=b_masked_w[j*8+:8];
    if(fill_recv_r+1==fill_requests_w)begin panel_ready_r[fill_slot_r]<=1;filling_r<=0;fill_k_r<=fill_k_r+32;fill_slot_r<=1-fill_slot_r;end
   end
   case({fifo_push_w,fifo_pop_w})
    2'b10:fifo_count_r<=fifo_count_r+1;
    2'b01:fifo_count_r<=fifo_count_r-1;
    default:begin end
   endcase
   if(fifo_push_w)begin result_fifo_r[fifo_wr_r]<={core_mscale,core_mtag,core_sums};fifo_wr_r<=fifo_wr_r+1'b1;end
   if(fifo_pop_w)begin fifo_rd_r<=fifo_rd_r+1'b1;bundle_r<=0;end
   else if(epi_sv&&epi_sr)bundle_r<=bundle_r+1;
   case({core_sv&&core_sr&&core_last,core_mv&&core_mr})
    2'b10:core_pending_r<=core_pending_r+1;
    2'b01:core_pending_r<=core_pending_r-1;
    default:begin end
   endcase
   case({epi_sv&&epi_sr,epi_mv&&epi_mr})
    2'b10:epi_pending_r<=epi_pending_r+1;
    2'b01:epi_pending_r<=epi_pending_r-1;
    default:begin end
   endcase
   if(epi_mv&&epi_mr&&epi_error&&error_r==0)begin error_r<=5;state_r<=ERROR_DRAIN;end
   if(operand_bad_w&&error_r==0)begin error_r<=5;state_r<=ERROR_DRAIN;end
   case(state_r)
    IDLE:if(cmd_valid&&cmd_ready)begin
     opcode_r<=cmd_opcode;payload_r<=cmd_payload;banks_r<=cmd_bank_ids;txn_r<=cmd_transaction_id;gens_r<=cmd_generations;
     descgens_r<=cmd_desc_generations;profiles_r<=cmd_profiles;owners_r<=cmd_desc_owner;
     layers_r<=cmd_layers;rows_desc_r<=cmd_rows;cols_desc_r<=cmd_cols;positions_r<=cmd_positions;
     present_r<=cmd_desc_present;data_valid_r<=cmd_data_valid;scale_valid_r<=cmd_scale_valid;busy_r<=cmd_desc_busy;
     error_r<=0;begun_r<=0;ai_r<=0;ar_r<=0;bi_r<=0;br_r<=0;
     kv_r<=0;npanel_r<=0;fifo_count_r<=0;fifo_rd_r<=0;fifo_wr_r<=0;bundle_r<=0;
     if(cmd_opcode==3)begin
      rows_r<=integer'(cmd_payload[24:19]);k_r<=integer'(cmd_payload[18:8]);n_r<=integer'(cmd_payload[7:0]);
      nstart_r<=integer'(cmd_payload[62:47]);ntotal_r<=integer'(cmd_payload[46:31]);mstart_r<=integer'(cmd_payload[30:25]);
      query_r<=0;length_r<=1;padded_r<=16;
     end else begin
      rows_r<=integer'(cmd_payload[16:11]);length_r<=integer'(cmd_payload[10:0]);query_r<=integer'(cmd_payload[26:17]);
      k_r<=cmd_opcode==6?64:integer'(cmd_payload[10:0]);n_r<=cmd_opcode==6?((integer'(cmd_payload[10:0])+15)/16)*16:64;
      nstart_r<=0;ntotal_r<=cmd_opcode==6?((integer'(cmd_payload[10:0])+15)/16)*16:576;mstart_r<=0;
      padded_r<=((integer'(cmd_payload[10:0])+15)/16)*16;
     end
     state_r<=CHECK;
    end
    CHECK:begin
     if(descriptor_error_w!=0)begin error_r<=descriptor_error_w;state_r<=ERROR_DRAIN;end
     else begin
      groups_r<=opcode_r==3?(mstart_r%16+rows_r+15)/16:(rows_r+15)/16;
      logical_rows_r<=opcode_r==3?rows_r:3*rows_r;astride_r<=(k_r+31)/32;
      a_scale_count_r<=opcode_r==3?(integer'(rows_desc_r[10:0])+15)/16:9*((rows_r+15)/16);
      b_scale_count_r<=opcode_r==3?(n_r+15)/16:opcode_r==6?3:12;
      state_r<=opcode_r==3?LOAD_AS:BEGIN_DST;
     end
    end
    BEGIN_DST:if(dst_begin_ready)begin
     if(dst_begin_error_code!=0)begin error_r<=dst_begin_error_code;state_r<=ERROR_DRAIN;end
     else begin begun_r<=1;state_r<=LOAD_AS;end
    end
    LOAD_AS:if(ar_r==(a_scale_count_r+7)/8)begin ai_r<=0;ar_r<=0;state_r<=LOAD_BS;end
    LOAD_BS:if(br_r==(b_scale_count_r+(opcode_r==3?7:3))/(opcode_r==3?8:4))begin bi_r<=0;br_r<=0;state_r<=VALID_S;end
    VALID_S:begin
     state_r<=LOAD_A;
     for(integer j=0;j<18;j=j+1)if(j<a_scale_count_r&&!valid_scale(a_scales_r[j]))begin error_r<=5;state_r<=ERROR_DRAIN;end
     for(integer j=0;j<12;j=j+1)if(j<b_scale_count_r&&!valid_scale(b_scales_r[j]))begin error_r<=5;state_r<=ERROR_DRAIN;end
    end
    LOAD_A:if(ar_r==a_requests_w)begin ai_r<=0;ar_r<=0;scale_i_r<=0;state_r<=SCALE_REQ;end
    SCALE_REQ:if(mul_sv&&mul_sr)state_r<=SCALE_WAIT;
    SCALE_WAIT:if(mul_mv)begin
     if(mul_mnf)begin error_r<=5;state_r<=ERROR_DRAIN;end
     else if(opcode_r==6)begin scale_ab_r<=mul_result;state_r<=SCALE_Q_REQ;end
     else begin combined_r[scale_i_r]<=mul_result;
      if(scale_i_r+1==scale_count_w)begin state_r<=RUN;panel_ready_r<=0;fill_k_r<=0;fill_slot_r<=0;fill_i_r<=0;fill_recv_r<=0;filling_r<=0;active_slot_r<=0;active_k_r<=0;issue_row_r<=0;issue_half_r<=0;end
      else begin scale_i_r<=scale_i_r+1;state_r<=SCALE_REQ;end
     end
    end
    SCALE_Q_REQ:if(mul_sv&&mul_sr)state_r<=SCALE_Q_WAIT;
    SCALE_Q_WAIT:if(mul_mv)begin
     if(mul_mnf)begin error_r<=5;state_r<=ERROR_DRAIN;end
     else begin combined_r[scale_i_r]<=mul_result;
      if(scale_i_r+1==scale_count_w)begin state_r<=RUN;panel_ready_r<=0;fill_k_r<=0;fill_slot_r<=0;fill_i_r<=0;fill_recv_r<=0;filling_r<=0;active_slot_r<=0;active_k_r<=0;issue_row_r<=0;issue_half_r<=0;end
      else begin scale_i_r<=scale_i_r+1;state_r<=SCALE_REQ;end
     end
    end
    RUN:begin
     if(!filling_r && !panel_ready_r[fill_slot_r] && fill_k_r<k_r)begin filling_r<=1;fill_i_r<=0;fill_recv_r<=0;end
     if(stage_capture_w)begin
      if(issue_row_r+1==logical_rows_r)begin
       issue_row_r<=0;
       if(issue_half_r==0&&active_k_r+16<k_r)issue_half_r<=1;
       else begin
        panel_ready_r[active_slot_r]<=0;active_slot_r<=1-active_slot_r;active_k_r<=active_k_r+32;issue_half_r<=0;
        if(active_k_r+32>=k_r)begin state_r<=WAIT_DRAIN;issue_row_r<=logical_rows_r;end
       end
      end else issue_row_r<=issue_row_r+1;
     end
    end
    WAIT_DRAIN:if(drain_w)state_r<=NEXT_PANEL;
    NEXT_PANEL:begin
     bi_r<=0;br_r<=0;ai_r<=0;ar_r<=0;scale_i_r<=0;
     if(npanel_r+16<n_r)begin npanel_r<=npanel_r+16;state_r<=SCALE_REQ;end
     else if(opcode_r!=3&&kv_r<2)begin kv_r<=kv_r+1;npanel_r<=0;state_r<=LOAD_A;end
     else state_r<=RESPONSE;
    end
    ERROR_DRAIN:if(drain_w)state_r<=INVALIDATE;
    INVALIDATE:if(dst_invalidate_ready)state_r<=RESPONSE;
    RESPONSE:if(resp_ready)state_r<=IDLE;
    default:state_r<=IDLE;
   endcase
   // Numerical faults dominate normal FSM advancement in the same cycle.
   if(error_r==0&&core_mv&&core_mr&&core_mnv!=core_mtag[36:32])begin error_r<=7;state_r<=ERROR_DRAIN;end
   if(error_r==0&&(operand_bad_w||epi_mv&&epi_mr&&epi_error))begin error_r<=5;state_r<=ERROR_DRAIN;end
  end
 end
endmodule
