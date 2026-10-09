module smollm2_isa_dispatcher(
 input logic clk,
 input logic resetn,
 input logic start,
 input logic [127:0] cmd_doutb,
 output logic busy,
 output logic done,
 output logic error,
 output logic [7:0] error_code,
 output logic [3:0] current_pc,
 output logic cmd_enb,
 output logic [3:0] cmd_addrb,
 output logic [3:0] engine_cmd_valid,
 output logic [15:0] engine_cmd_opcode,
 output logic [447:0] engine_cmd_payload,
 output logic [47:0] engine_cmd_bank_ids,
 output logic [127:0] engine_cmd_transaction_id,
 output logic [383:0] engine_cmd_generations,
 output logic [11:0] engine_cmd_desc_present,
 output logic [59:0] engine_cmd_profiles,
 output logic [131:0] engine_cmd_rows,
 output logic [191:0] engine_cmd_cols,
 output logic [119:0] engine_cmd_positions,
 output logic [59:0] engine_cmd_layers,
 output logic [383:0] engine_cmd_desc_generations,
 output logic [11:0] engine_cmd_data_valid,
 output logic [11:0] engine_cmd_scale_valid,
 output logic [11:0] engine_cmd_desc_busy,
 output logic [59:0] engine_cmd_desc_owner,
 output logic [3:0] engine_cmd_b7_static_valid,
 output logic [255:0] engine_cmd_embedding_lanes,
 output logic [127:0] engine_cmd_embedding_lane_valid,
 input logic [3:0] engine_cmd_ready,
 input logic [3:0] engine_resp_valid,
 input logic [127:0] engine_resp_transaction_id,
 input logic [11:0] engine_resp_used_bank_mask,
 input logic [7:0] engine_resp_used_bank_count,
 input logic [47:0] engine_resp_bank_ids,
 input logic [383:0] engine_resp_generations,
 input logic [31:0] engine_resp_error_code,
 output logic [3:0] engine_resp_ready,
 input logic [15:0] bank_busy,
 input logic [79:0] bank_owner_port,
 input logic [15:0] bank_desc_present,
 input logic [79:0] bank_profiles,
 input logic [175:0] bank_rows,
 input logic [255:0] bank_cols,
 input logic [159:0] bank_positions,
 input logic [79:0] bank_layers,
 input logic [511:0] bank_generations,
 input logic [15:0] bank_data_valid,
 input logic [15:0] bank_scale_valid,
 input logic bank_b7_static_valid,
 input logic bank_b7_rope_valid,
 input logic [63:0] bank_embedding_lanes,
 input logic [31:0] bank_embedding_lane_valid,
 output logic acquire_valid,
 output logic [31:0] acquire_transaction_id,
 output logic [2:0] acquire_used_bank_mask,
 output logic [11:0] acquire_bank_ids,
 output logic [14:0] acquire_roles,
 output logic [95:0] acquire_generations,
 input logic acquire_ready,
 input logic [7:0] acquire_error_code,
 output logic release_valid,
 output logic [31:0] release_transaction_id,
 output logic [2:0] release_used_bank_mask,
 output logic [11:0] release_bank_ids,
 output logic [14:0] release_roles,
 output logic [95:0] release_generations,
 input logic release_ready,
 input logic [7:0] release_error_code,
 output logic cfg_valid,
 output logic [31:0] cfg_transaction_id,
 output logic [3:0] cfg_bank,
 output logic [4:0] cfg_profile,
 output logic [10:0] cfg_rows,
 output logic [15:0] cfg_cols,
 output logic [9:0] cfg_position,
 output logic [4:0] cfg_layer,
 output logic [1:0] cfg_component,
 output logic [31:0] cfg_generation,
 output logic cfg_resp_ready,
 input logic cfg_ready,
 input logic cfg_resp_valid,
 input logic [31:0] cfg_resp_transaction_id,
 input logic [7:0] cfg_resp_error_code
);
 // Adapted from the v2 exclusive dispatcher fetch/PC/issue/drain semantic
 // skeleton. New identity and retained-offer logic does not inherit its PASS.
 typedef enum logic[3:0] {IDLE,FETCH,WAIT1,WAIT2,VERIFY,ELIGIBLE,
  OFFER,CONFIG_OFFER,FENCE_DRAIN,ERROR_DRAIN,END_DRAIN,DONE_STATE,ERROR_STATE} state_t;
 state_t state_r;
 logic[3:0]pc_r;logic[127:0]record_r;
 logic[31:0]next_txn_r;logic exhausted_r;logic[7:0]error_r;
 logic[3:0]op_w;logic[111:0]pay_w;logic[11:0]ids_w;
 logic[3:0]b0_w,b1_w,b2_w;logic[1:0]slot_w,offer_slot_r;
 logic[2:0]mask_w,offer_mask_r;logic[14:0]roles_w,offer_roles_r;
 logic[7:0]static_error_w;logic free_w;
 logic[127:0]offer_record_r;logic[31:0]offer_txn_r;
 logic[95:0]offer_gens_r;logic[2:0]offer_present_r,offer_data_r,offer_scale_r;
 logic[14:0]offer_profiles_r,offer_layers_r;logic[32:0]offer_rows_r;
 logic[47:0]offer_cols_r;logic[29:0]offer_positions_r;
 logic offer_static_r;logic[63:0]offer_embedding_r;logic[31:0]offer_embedding_valid_r;
 logic[3:0]active_r,completed_r;
 logic[31:0]track_txn_r[0:3];logic[11:0]track_ids_r[0:3];
 logic[95:0]track_gens_r[0:3];logic[14:0]track_roles_r[0:3];
 logic[2:0]track_mask_r[0:3];logic[1:0]track_count_r[0:3];
 logic cfg_pending_r;logic[31:0]cfg_txn_r;
 logic resp_select_valid_w,release_select_valid_w;
 logic[1:0]resp_slot_w,release_slot_w,release_slot_r;logic release_pending_r;logic resp_match_w,resp_fire_w;
 logic issue_fire_w,cfg_fire_w,release_fire_w,cfg_resp_fire_w;
 logic pending_w;logic[7:0]event_error_w;
 logic[10:0]mcount_w;logic[11:0]msum_w;logic[16:0]nsum_w;
 logic[32:0]dma_ddr_end_w,dma_local_end_w;logic[31:0]capacity_w;
 logic[10:0]attrows_w;logic[11:0]attsum_w;
 logic config_profile_ok_w,config_shape_ok_w;
 assign op_w=record_r[127:124];assign pay_w=record_r[111:0];
 assign b0_w=record_r[123:120];assign b1_w=record_r[119:116];assign b2_w=record_r[115:112];
 assign ids_w={b2_w,b1_w,b0_w};
 assign pending_w=(|active_r)||cfg_pending_r||(|bank_busy);
 assign busy=state_r!=IDLE&&state_r!=DONE_STATE&&state_r!=ERROR_STATE;
 assign done=state_r==DONE_STATE;assign error=error_r!=0;assign error_code=error_r;
 assign current_pc=pc_r;assign cmd_enb=resetn&&state_r==FETCH;assign cmd_addrb=pc_r;
 assign mcount_w={5'b0,pay_w[24:19]};assign msum_w={6'b0,pay_w[30:25]}+{1'b0,mcount_w};
 assign nsum_w={1'b0,pay_w[62:47]}+{9'b0,pay_w[7:0]};
 assign attrows_w={5'b0,pay_w[16:11]};assign attsum_w={2'b0,pay_w[26:17]}+{1'b0,attrows_w};
 assign dma_ddr_end_w={1'b0,pay_w[56:25]}+{10'b0,pay_w[79:57]};
 assign dma_local_end_w={1'b0,pay_w[111:80]}+{10'b0,pay_w[79:57]};
 always @* begin
  capacity_w=0;
  case(b0_w)
   0,1,2,4,5,11:capacity_w=36864;3:capacity_w=295424;
   6:capacity_w=12288;7:capacity_w=6016;8:capacity_w=196640;
   9:capacity_w=196672;10:capacity_w=589824;12:capacity_w=98304;
   13:capacity_w=295008;14:capacity_w=18528;15:capacity_w=295040;
   default:capacity_w=0;
  endcase
 end
 // Exact static legality from pinned isa_codec.validate_command. Runtime
 // source descriptor/coverage/numeric checks remain the real executor's job.
 always @* begin
  slot_w=0;mask_w=0;roles_w=0;static_error_w=0;
  config_profile_ok_w=0;config_shape_ok_w=0;
  case(b0_w)
   0:config_profile_ok_w=pay_w[4:0]==1;
   1:config_profile_ok_w=pay_w[4:0]==2;
   2:config_profile_ok_w=pay_w[4:0]==3;
   3:config_profile_ok_w=pay_w[4:0]==4||pay_w[4:0]==5||pay_w[4:0]==6;
   4:config_profile_ok_w=pay_w[4:0]==7;
   5:config_profile_ok_w=pay_w[4:0]==8||pay_w[4:0]==9;
   6:config_profile_ok_w=pay_w[4:0]==10;
   7:config_profile_ok_w=pay_w[4:0]==11;
   8:config_profile_ok_w=pay_w[4:0]==12||pay_w[4:0]==13;
   9:config_profile_ok_w=pay_w[4:0]==14||pay_w[4:0]==15;
   10:config_profile_ok_w=pay_w[4:0]==16||pay_w[4:0]==17||pay_w[4:0]==18;
   11:config_profile_ok_w=pay_w[4:0]==19;
   12:config_profile_ok_w=pay_w[4:0]==20;
   13:config_profile_ok_w=pay_w[4:0]==21||pay_w[4:0]==22;
   14:config_profile_ok_w=pay_w[4:0]==23;
   15:config_profile_ok_w=pay_w[4:0]==4;
   default:config_profile_ok_w=0;
  endcase
  case(pay_w[4:0])
   4:config_shape_ok_w=pay_w[15:5]>=1&&pay_w[15:5]<=192&&(pay_w[31:16]==576||pay_w[31:16]==1536);
   5:config_shape_ok_w=pay_w[15:5]==1&&pay_w[31:16]==576;
   11:config_shape_ok_w=pay_w[31:16]==64&&((pay_w[48:47]==2&&pay_w[15:5]==30&&pay_w[41:32]==0)||
      (pay_w[48:47]!=2&&pay_w[15:5]>=1&&pay_w[15:5]<=32&&({1'b0,pay_w[41:32]}+pay_w[15:5])<=1024));
   12,14:config_shape_ok_w=pay_w[15:5]>=1&&pay_w[15:5]<=1024&&pay_w[31:16]==192&&pay_w[46:42]<30;
   16,17,22:config_shape_ok_w=pay_w[15:5]>=1&&pay_w[15:5]<=32&&pay_w[31:16]>=1&&pay_w[31:16]<=1024&&
      ({6'b0,pay_w[41:32]}+{5'b0,pay_w[15:5]})<=pay_w[31:16];
   21:config_shape_ok_w=pay_w[15:5]>=1&&pay_w[15:5]<=32&&(pay_w[31:16]==576||pay_w[31:16]==1536);
   20:config_shape_ok_w=pay_w[15:5]==1&&pay_w[31:16]==49152;
   8,10:config_shape_ok_w=pay_w[15:5]>=1&&pay_w[15:5]<=32&&pay_w[31:16]==192;
   13,15,18:config_shape_ok_w=pay_w[15:5]>=1&&pay_w[15:5]<=32&&pay_w[31:16]==1536;
   default:config_shape_ok_w=pay_w[15:5]>=1&&pay_w[15:5]<=32&&pay_w[31:16]==576;
  endcase
  if(!(pay_w[4:0]==11||pay_w[4:0]==16||pay_w[4:0]==17||pay_w[4:0]==22)&&pay_w[41:32]!=0)config_shape_ok_w=0;
  if(!(pay_w[4:0]==12||pay_w[4:0]==14)&&pay_w[46:42]!=0)config_shape_ok_w=0;
  case(op_w)
   0,11:begin if(pay_w!=0||ids_w!=0)static_error_w=1;end
   1,2:begin
    slot_w=op_w==1?0:1;mask_w=1;roles_w[4:0]=op_w==1?5'd1:5'd2;
    if(b1_w!=0||b2_w!=0)static_error_w=1;
    else if(pay_w[79:57]==0||pay_w[83:80]!=0||pay_w[60:57]!=0||pay_w[28:25]!=0||
      dma_ddr_end_w>33'h100000000||dma_local_end_w>{1'b0,capacity_w})static_error_w=3;
    else if(pay_w[24:0]!=0&&(op_w!=1||b0_w!=3||pay_w[24:3]!=0||!pay_w[0]||pay_w[79:57]!=16||
      pay_w[111:80]<294912||pay_w[111:80]>=295424))static_error_w=3;
   end
   3:begin
    slot_w=2;mask_w=7;roles_w={5'd5,5'd4,5'd3};
    if(pay_w[111:63]!=0)static_error_w=1;
    else if(b0_w!=13||(b1_w!=3&&b1_w!=15)||b0_w==b1_w||b0_w==b2_w||b1_w==b2_w)static_error_w=2;
    else if(mcount_w<1||mcount_w>32||msum_w>32||(pay_w[18:8]!=576&&pay_w[18:8]!=1536)||
      pay_w[7:0]<1||pay_w[7:0]>192||pay_w[46:31]<1||pay_w[46:31]>49152||pay_w[52:47]!=0||nsum_w>{1'b0,pay_w[46:31]})static_error_w=3;
    else case(b2_w)
     1,4:if(pay_w[46:31]!=576)static_error_w=3;
     5,6:if(pay_w[46:31]!=192)static_error_w=3;
     8,9:if(pay_w[46:31]!=1536||mcount_w>32)static_error_w=3;
     12:if(pay_w[46:31]!=49152||mcount_w!=1)static_error_w=3;
     default:static_error_w=2;
    endcase
   end
   6,8:begin
    slot_w=2;mask_w=7;roles_w=op_w==6?{5'd13,5'd12,5'd11}:{5'd17,5'd16,5'd15};
    if(pay_w[111:27]!=0)static_error_w=1;
    else if((op_w==6&&ids_w!={4'd10,4'd8,4'd14})||(op_w==8&&ids_w!={4'd11,4'd9,4'd13}))static_error_w=2;
    else if(attrows_w<1||attrows_w>32||pay_w[10:0]<1||pay_w[10:0]>1024||attsum_w>{1'b0,pay_w[10:0]})static_error_w=3;
   end
   13,14:begin
    slot_w=3;mask_w=5;roles_w=op_w==14?{5'd25,5'd0,5'd24}:{5'd23,5'd0,5'd21};
    if(op_w==13&&(pay_w[2:0]==2||pay_w[2:0]==3))begin mask_w=7;roles_w[9:5]=22;end
    if(pay_w[111:52]!=0)static_error_w=1;
    else if((!mask_w[1]&&b1_w!=0)||b0_w==b2_w||(mask_w[1]&&(b1_w==b0_w||b1_w==b2_w)))static_error_w=2;
    else if(pay_w[14:9]<1||pay_w[14:9]>32||({1'b0,pay_w[8:3]}+{1'b0,pay_w[14:9]})>32)static_error_w=3;
    else if(op_w==14)begin
     if(ids_w!={4'd0,4'd0,4'd3}||pay_w[2:0]!=0||pay_w[25:15]!=576||pay_w[8:3]!=0||pay_w[51:26]!=0)static_error_w=3;
    end else case(pay_w[2:0])
     0:if((b0_w!=2&&b0_w!=10&&b0_w!=11)||b2_w!=13||(pay_w[25:15]!=576&&pay_w[25:15]!=1536)||pay_w[51:26]!=0)static_error_w=3;
     1,2,3:begin
      if(pay_w[25:15]!=64||pay_w[8:3]!=0||pay_w[46:26]!=0)static_error_w=3;
      else if(pay_w[2:0]==1&&(ids_w!={4'd14,4'd0,4'd4}||pay_w[51:47]!=0))static_error_w=3;
      else if(pay_w[2:0]==2&&(ids_w!={4'd8,4'd7,4'd5}||pay_w[51:47]>=30))static_error_w=3;
      else if(pay_w[2:0]==3&&(ids_w!={4'd9,4'd7,4'd6}||pay_w[51:47]>=30))static_error_w=3;
     end
     4:if(ids_w!={4'd13,4'd0,4'd10}||pay_w[25:15]!=pay_w[36:26]||pay_w[36:26]<1||pay_w[36:26]>1024||
       pay_w[8:3]!=0||pay_w[51:47]!=0||({2'b0,pay_w[46:37]}+{6'b0,pay_w[14:9]})>{1'b0,pay_w[36:26]})static_error_w=3;
     default:static_error_w=3;
    endcase
   end
   15:begin
    if(pay_w[111:81]!=0||b1_w!=0||b2_w!=0)static_error_w=1;
    else if(!config_profile_ok_w||pay_w[80:49]==0||(b0_w==7?pay_w[48:47]>2:pay_w[48:47]!=0))static_error_w=2;
    else if(!config_shape_ok_w)static_error_w=3;
   end
   default:static_error_w=1;
  endcase
  free_w=1;
  for(int n=0;n<3;n++)if(mask_w[n]&&bank_busy[ids_w[n*4+:4]])free_w=0;
 end
 always @* begin
  engine_cmd_valid=0;engine_cmd_opcode=0;engine_cmd_payload=0;engine_cmd_bank_ids=0;
  engine_cmd_transaction_id=0;engine_cmd_generations=0;engine_cmd_desc_present=0;
  engine_cmd_profiles=0;engine_cmd_rows=0;engine_cmd_cols=0;engine_cmd_positions=0;
  engine_cmd_layers=0;engine_cmd_desc_generations=0;engine_cmd_data_valid=0;
  engine_cmd_scale_valid=0;engine_cmd_desc_busy=0;engine_cmd_desc_owner=0;
  engine_cmd_b7_static_valid=0;engine_cmd_embedding_lanes=0;engine_cmd_embedding_lane_valid=0;
  if(state_r==OFFER)begin
   engine_cmd_valid[offer_slot_r]=resetn;
   engine_cmd_opcode[offer_slot_r*4+:4]=offer_record_r[127:124];
   engine_cmd_payload[offer_slot_r*112+:112]=offer_record_r[111:0];
   engine_cmd_bank_ids[offer_slot_r*12+:12]={offer_record_r[115:112],offer_record_r[119:116],offer_record_r[123:120]};
   engine_cmd_transaction_id[offer_slot_r*32+:32]=offer_txn_r;
   engine_cmd_generations[offer_slot_r*96+:96]=offer_gens_r;
   engine_cmd_desc_generations[offer_slot_r*96+:96]=offer_gens_r;
   engine_cmd_desc_present[offer_slot_r*3+:3]=offer_present_r;
   engine_cmd_profiles[offer_slot_r*15+:15]=offer_profiles_r;
   engine_cmd_rows[offer_slot_r*33+:33]=offer_rows_r;
   engine_cmd_cols[offer_slot_r*48+:48]=offer_cols_r;
   engine_cmd_positions[offer_slot_r*30+:30]=offer_positions_r;
   engine_cmd_layers[offer_slot_r*15+:15]=offer_layers_r;
   engine_cmd_data_valid[offer_slot_r*3+:3]=offer_data_r;
   engine_cmd_scale_valid[offer_slot_r*3+:3]=offer_scale_r;
   engine_cmd_desc_busy[offer_slot_r*3+:3]=offer_mask_r;
   engine_cmd_desc_owner[offer_slot_r*15+:15]=offer_roles_r;
   engine_cmd_b7_static_valid[offer_slot_r]=offer_static_r;
   engine_cmd_embedding_lanes[offer_slot_r*64+:64]=offer_embedding_r;
   engine_cmd_embedding_lane_valid[offer_slot_r*32+:32]=offer_embedding_valid_r;
  end
 end
 assign issue_fire_w=|(engine_cmd_valid&engine_cmd_ready);
 always @* begin
  acquire_valid=issue_fire_w;acquire_transaction_id=next_txn_r;
  acquire_used_bank_mask=mask_w;acquire_bank_ids=ids_w;acquire_roles=roles_w;acquire_generations=0;
  for(int n=0;n<3;n++)if(mask_w[n])acquire_generations[n*32+:32]=bank_generations[ids_w[n*4+:4]*32+:32];
  if(state_r==OFFER)begin
   acquire_transaction_id=offer_txn_r;acquire_used_bank_mask=offer_mask_r;
   acquire_bank_ids={offer_record_r[115:112],offer_record_r[119:116],offer_record_r[123:120]};
   acquire_roles=offer_roles_r;acquire_generations=offer_gens_r;
  end
 end
 always @* begin
  resp_select_valid_w=0;resp_slot_w=0;engine_resp_ready=0;
  for(int s=0;s<4;s++)if(engine_resp_valid[s]&&!resp_select_valid_w)begin
   resp_select_valid_w=1;resp_slot_w=2'(s);
  end
  if(resp_select_valid_w)engine_resp_ready[resp_slot_w]=resetn;
  resp_match_w=0;
  if(resp_select_valid_w)resp_match_w=active_r[resp_slot_w]&&!completed_r[resp_slot_w]&&
   engine_resp_transaction_id[resp_slot_w*32+:32]==track_txn_r[resp_slot_w]&&
   engine_resp_used_bank_mask[resp_slot_w*3+:3]==track_mask_r[resp_slot_w]&&
   engine_resp_used_bank_count[resp_slot_w*2+:2]==track_count_r[resp_slot_w]&&
   engine_resp_bank_ids[resp_slot_w*12+:12]==track_ids_r[resp_slot_w]&&
   engine_resp_generations[resp_slot_w*96+:96]==track_gens_r[resp_slot_w];
  if(resp_select_valid_w&&issue_fire_w&&resp_slot_w==offer_slot_r&&!active_r[resp_slot_w])
   resp_match_w=engine_resp_transaction_id[resp_slot_w*32+:32]==offer_txn_r&&
    engine_resp_used_bank_mask[resp_slot_w*3+:3]==offer_mask_r&&
    engine_resp_used_bank_count[resp_slot_w*2+:2]==({1'b0,offer_mask_r[0]}+{1'b0,offer_mask_r[1]}+{1'b0,offer_mask_r[2]})&&
    engine_resp_bank_ids[resp_slot_w*12+:12]==acquire_bank_ids&&engine_resp_generations[resp_slot_w*96+:96]==offer_gens_r;
  release_select_valid_w=0;release_slot_w=0;
  for(int s=0;s<4;s++)if(completed_r[s]&&!release_select_valid_w)begin
   release_select_valid_w=1;release_slot_w=2'(s);
  end
  release_valid=resetn&&release_pending_r;
  release_transaction_id=track_txn_r[release_slot_r];release_used_bank_mask=track_mask_r[release_slot_r];
  release_bank_ids=track_ids_r[release_slot_r];release_roles=track_roles_r[release_slot_r];
  release_generations=track_gens_r[release_slot_r];
 end
 assign resp_fire_w=resp_select_valid_w&&engine_resp_ready[resp_slot_w];
 assign release_fire_w=release_valid&&release_ready&&release_error_code==0;
 assign cfg_valid=resetn&&state_r==CONFIG_OFFER;
 assign cfg_transaction_id=offer_txn_r;assign cfg_bank=offer_record_r[123:120];
 assign cfg_profile=offer_record_r[4:0];assign cfg_rows=offer_record_r[15:5];
 assign cfg_cols=offer_record_r[31:16];assign cfg_position=offer_record_r[41:32];
 assign cfg_layer=offer_record_r[46:42];assign cfg_component=offer_record_r[48:47];
 assign cfg_generation=offer_record_r[80:49];
 assign cfg_fire_w=cfg_valid&&cfg_ready;assign cfg_resp_ready=resetn;
 assign cfg_resp_fire_w=cfg_resp_valid&&cfg_resp_ready;
 always @* begin
  event_error_w=0;
  for(int s=0;s<4;s++)for(int n=0;n<3;n++)if(active_r[s]&&track_mask_r[s][n])
   if(!bank_busy[track_ids_r[s][n*4+:4]]||bank_owner_port[track_ids_r[s][n*4+:4]*5+:5]!=track_roles_r[s][n*5+:5])event_error_w=7;
  if(issue_fire_w&&(!acquire_ready||acquire_error_code!=0))event_error_w=7;
  if(release_valid&&release_ready&&release_error_code!=0)event_error_w=7;
  if(cfg_resp_fire_w)begin
   if(!(cfg_pending_r&&cfg_resp_transaction_id==cfg_txn_r)&&!(cfg_fire_w&&cfg_resp_transaction_id==offer_txn_r))event_error_w=7;
   else if(cfg_resp_error_code!=0)event_error_w=cfg_resp_error_code;
  end
  if(resp_fire_w)begin
   if(!resp_match_w)event_error_w=7;
   else if(engine_resp_error_code[resp_slot_w*8+:8]!=0)event_error_w=engine_resp_error_code[resp_slot_w*8+:8];
  end
 end
 always_ff @(posedge clk)begin
  if(!resetn)begin
   state_r<=IDLE;pc_r<=0;record_r<=0;next_txn_r<=1;exhausted_r<=0;error_r<=0;
   offer_slot_r<=0;offer_mask_r<=0;offer_roles_r<=0;offer_record_r<=0;offer_txn_r<=0;
   offer_gens_r<=0;offer_present_r<=0;offer_data_r<=0;offer_scale_r<=0;
   offer_profiles_r<=0;offer_layers_r<=0;offer_rows_r<=0;offer_cols_r<=0;offer_positions_r<=0;
   offer_static_r<=0;offer_embedding_r<=0;offer_embedding_valid_r<=0;
   active_r<=0;completed_r<=0;cfg_pending_r<=0;cfg_txn_r<=0;release_pending_r<=0;release_slot_r<=0;
   for(int s=0;s<4;s++)begin
    track_txn_r[s]<=0;track_ids_r[s]<=0;track_gens_r[s]<=0;track_roles_r[s]<=0;track_mask_r[s]<=0;track_count_r[s]<=0;
   end
  end else begin
   if(error_r==0&&event_error_w!=0)error_r<=event_error_w;
   if(resp_fire_w&&resp_match_w)completed_r[resp_slot_w]<=1;
   if(!release_pending_r&&release_select_valid_w)begin release_pending_r<=1;release_slot_r<=release_slot_w;end
   if(release_fire_w)begin active_r[release_slot_r]<=0;completed_r[release_slot_r]<=0;release_pending_r<=0;end
   if(cfg_resp_fire_w&&cfg_pending_r&&cfg_resp_transaction_id==cfg_txn_r)cfg_pending_r<=0;
   if(issue_fire_w)begin
    active_r[offer_slot_r]<=1;completed_r[offer_slot_r]<=resp_fire_w&&resp_match_w&&resp_slot_w==offer_slot_r;
    track_txn_r[offer_slot_r]<=offer_txn_r;
    track_ids_r[offer_slot_r]<={offer_record_r[115:112],offer_record_r[119:116],offer_record_r[123:120]};
    track_gens_r[offer_slot_r]<=offer_gens_r;track_roles_r[offer_slot_r]<=offer_roles_r;
    track_mask_r[offer_slot_r]<=offer_mask_r;
    track_count_r[offer_slot_r]<={1'b0,offer_mask_r[0]}+{1'b0,offer_mask_r[1]}+{1'b0,offer_mask_r[2]};
   end
   if(cfg_fire_w)begin cfg_pending_r<=!(cfg_resp_fire_w&&cfg_resp_transaction_id==offer_txn_r);cfg_txn_r<=offer_txn_r;end
   if(issue_fire_w||cfg_fire_w)begin
    if(next_txn_r==32'hffffffff)exhausted_r<=1;
    else next_txn_r<=next_txn_r+1;
   end
   case(state_r)
    IDLE,DONE_STATE,ERROR_STATE:if(start&&!pending_w&&event_error_w==0)begin pc_r<=0;error_r<=0;state_r<=FETCH;end
    FETCH:state_r<=WAIT1;
    WAIT1:state_r<=WAIT2;
    WAIT2:begin record_r<=cmd_doutb;state_r<=VERIFY;end
    VERIFY:begin
     if(static_error_w!=0)begin if(error_r==0&&event_error_w==0)error_r<=static_error_w;state_r<=ERROR_DRAIN;end
     else if(op_w==0)state_r<=END_DRAIN;
     else if(op_w==11)state_r<=FENCE_DRAIN;
     else if(exhausted_r)begin if(error_r==0&&event_error_w==0)error_r<=7;state_r<=ERROR_DRAIN;end
     else state_r<=ELIGIBLE;
    end
    ELIGIBLE:begin
     if(op_w==15)begin
      if(!cfg_pending_r&&!bank_busy[b0_w])begin offer_record_r<=record_r;offer_txn_r<=next_txn_r;state_r<=CONFIG_OFFER;end
     end else if(free_w&&!active_r[slot_w])begin
      if(acquire_error_code!=0)begin if(error_r==0&&event_error_w==0)error_r<=7;state_r<=ERROR_DRAIN;end
      else if(acquire_ready)begin
       offer_record_r<=record_r;offer_txn_r<=next_txn_r;offer_slot_r<=slot_w;offer_mask_r<=mask_w;offer_roles_r<=roles_w;
       offer_static_r<=bank_b7_static_valid;offer_embedding_r<=bank_embedding_lanes;offer_embedding_valid_r<=bank_embedding_lane_valid;
       for(int n=0;n<3;n++)begin
        offer_gens_r[n*32+:32]<=mask_w[n]?bank_generations[ids_w[n*4+:4]*32+:32]:32'b0;
        offer_present_r[n]<=mask_w[n]&&bank_desc_present[ids_w[n*4+:4]];
        offer_profiles_r[n*5+:5]<=mask_w[n]?bank_profiles[ids_w[n*4+:4]*5+:5]:5'b0;
        offer_rows_r[n*11+:11]<=mask_w[n]?bank_rows[ids_w[n*4+:4]*11+:11]:11'b0;
        offer_cols_r[n*16+:16]<=mask_w[n]?bank_cols[ids_w[n*4+:4]*16+:16]:16'b0;
        offer_positions_r[n*10+:10]<=mask_w[n]?bank_positions[ids_w[n*4+:4]*10+:10]:10'b0;
        offer_layers_r[n*5+:5]<=mask_w[n]?bank_layers[ids_w[n*4+:4]*5+:5]:5'b0;
        offer_data_r[n]<=mask_w[n]&&bank_data_valid[ids_w[n*4+:4]];
        offer_scale_r[n]<=mask_w[n]&&bank_scale_valid[ids_w[n*4+:4]];
       end
       state_r<=OFFER;
      end
     end
    end
    OFFER:if(issue_fire_w)begin
     if(pc_r==15)begin if(error_r==0&&event_error_w==0)error_r<=1;state_r<=ERROR_DRAIN;end
     else begin pc_r<=pc_r+1;state_r<=FETCH;end
    end
    CONFIG_OFFER:if(cfg_fire_w)begin
     if(pc_r==15)begin if(error_r==0&&event_error_w==0)error_r<=1;state_r<=ERROR_DRAIN;end
     else begin pc_r<=pc_r+1;state_r<=FETCH;end
    end
    FENCE_DRAIN:if(!pending_w)begin
     if(pc_r==15)begin if(error_r==0&&event_error_w==0)error_r<=1;state_r<=ERROR_DRAIN;end
     else begin pc_r<=pc_r+1;state_r<=FETCH;end
    end
    END_DRAIN:if(!pending_w)state_r<=DONE_STATE;
    ERROR_DRAIN:if(!pending_w)state_r<=ERROR_STATE;
    default:begin state_r<=ERROR_STATE;end
   endcase
   // An asynchronous failure halts only new offers. Existing command/config
   // offers remain live, including their atomic acquisition, until accepted.
   if(busy&&state_r!=ERROR_DRAIN&&(error_r!=0||event_error_w!=0))begin
    if((state_r!=OFFER||issue_fire_w)&&(state_r!=CONFIG_OFFER||cfg_fire_w))state_r<=ERROR_DRAIN;
   end
  end
 end
endmodule
