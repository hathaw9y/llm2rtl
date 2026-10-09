module smollm2_dma_transaction_bridge (
    input logic clk,
    input logic resetn,
    input logic enable_new_commands,
    input logic [1:0] cmd_valid,
    input logic [7:0] cmd_opcode,
    input logic [223:0] cmd_payload,
    input logic [23:0] cmd_bank_ids,
    input logic [63:0] cmd_transaction_id,
    input logic [191:0] cmd_generations,
    input logic [1:0] cmd_desc_present,
    input logic [9:0] cmd_profile,
    input logic [21:0] cmd_rows,
    input logic [31:0] cmd_cols,
    input logic [19:0] cmd_position,
    input logic [9:0] cmd_layer,
    input logic [1:0] cmd_data_valid,
    input logic [1:0] cmd_scale_valid,
    input logic [1:0] cmd_desc_busy,
    input logic [9:0] cmd_desc_owner,
    input logic [63:0] cmd_embedding_lane_valid,
    input logic [10:0] bank_b7_rope_rows,
    input logic [31:0] bank_b7_rope_generation,
    input logic [31:0] bank_b7_static_generation,
    input logic bank_b7_rope_valid,
    input logic bank_b7_static_valid,
    input logic [15:0] bank_ready,
    input logic [15:0] bank_quiescent,
    input logic [15:0] wr_pending,
    input logic [15:0] coverage_pending,
    input logic mm2s_wr_ready,
    input logic mm2s_wr_commit,
    input logic s2mm_rd_ready,
    input logic s2mm_rd_resp_valid,
    input logic [127:0] s2mm_rd_data,
    input logic embedding_ready,
    input logic [7:0] embedding_error_code,
    input logic invalidate_ready,
    input logic [7:0] invalidate_error_code,
    input logic [1:0] resp_ready,
    input logic m_axis_mm2s_cmd_tready,
    input logic [127:0] s_axis_mm2s_tdata,
    input logic [15:0] s_axis_mm2s_tkeep,
    input logic s_axis_mm2s_tvalid,
    input logic s_axis_mm2s_tlast,
    input logic [7:0] s_axis_mm2s_sts_tdata,
    input logic s_axis_mm2s_sts_tkeep,
    input logic s_axis_mm2s_sts_tvalid,
    input logic s_axis_mm2s_sts_tlast,
    input logic m_axis_s2mm_cmd_tready,
    input logic m_axis_s2mm_tready,
    input logic [7:0] s_axis_s2mm_sts_tdata,
    input logic s_axis_s2mm_sts_tkeep,
    input logic s_axis_s2mm_sts_tvalid,
    input logic s_axis_s2mm_sts_tlast,
    output logic [1:0] cmd_ready,
    output logic [1:0] resp_valid,
    output logic [63:0] resp_transaction_id,
    output logic [5:0] resp_used_bank_mask,
    output logic [3:0] resp_used_bank_count,
    output logic [23:0] resp_bank_ids,
    output logic [191:0] resp_generations,
    output logic [15:0] resp_error_code,
    output logic mm2s_wr_valid,
    output logic [3:0] mm2s_wr_bank,
    output logic [18:0] mm2s_wr_word_address,
    output logic [127:0] mm2s_wr_data,
    output logic [15:0] mm2s_wr_strb,
    output logic [31:0] mm2s_wr_transaction_id,
    output logic [31:0] mm2s_wr_generation,
    output logic [4:0] mm2s_wr_role,
    output logic s2mm_rd_valid,
    output logic [3:0] s2mm_rd_bank,
    output logic [18:0] s2mm_rd_word_address,
    output logic embedding_valid,
    output logic [31:0] embedding_transaction_id,
    output logic [4:0] embedding_role,
    output logic [31:0] embedding_generation,
    output logic [4:0] embedding_row,
    output logic [1:0] embedding_lane,
    output logic invalidate_valid,
    output logic [31:0] invalidate_transaction_id,
    output logic [4:0] invalidate_role,
    output logic [3:0] invalidate_bank,
    output logic [31:0] invalidate_generation,
    output logic [1:0] invalidate_component,
    output logic [1:0] faulted,
    output logic [15:0] fault_reason,
    output logic [7:0] fault_bank,
    output logic [63:0] fault_transaction_id,
    output logic [15:0] fault_raw_status,
    output logic [7:0] fault_received_tag,
    output logic [7:0] fault_internal_tag,
    output logic [1:0] busy,
    output logic [71:0] m_axis_mm2s_cmd_tdata,
    output logic m_axis_mm2s_cmd_tvalid,
    output logic s_axis_mm2s_tready,
    output logic s_axis_mm2s_sts_tready,
    output logic [71:0] m_axis_s2mm_cmd_tdata,
    output logic m_axis_s2mm_cmd_tvalid,
    output logic [127:0] m_axis_s2mm_tdata,
    output logic [15:0] m_axis_s2mm_tkeep,
    output logic m_axis_s2mm_tvalid,
    output logic m_axis_s2mm_tlast,
    output logic s_axis_s2mm_sts_tready
);

  // Outer transactions remain live through native/coverage/metadata barriers.
  typedef enum logic [2:0] {IDLE, CHECK, VALIDATE, OFFER, ACTIVE, BARRIER, RESPONSE, FAULT} state_t;
  state_t state [2];
  logic [3:0] bank_r[2];
  logic [31:0] txn_r[2], gen_r[2], epoch_r[2];
  logic [111:0] payload_r[2];
  logic [4:0] profile_r[2];
  logic [10:0] rows_r[2];
  logic [15:0] cols_r[2];
  logic [9:0] position_r[2];
  logic [4:0] layer_r[2];
  logic [31:0] lane_valid_r[2];
  logic present_r[2], data_valid_r[2], scale_valid_r[2], owner_ok_r[2], tuple_ok_r[2];
  logic [10:0] rope_rows_r[2];
  logic rope_valid_r[2], static_valid_r[2];
  logic [31:0] rope_gen_r[2], static_gen_r[2];
  logic [1:0] component_r[2];
  logic [7:0] clean_error_r[2];
  logic [3:0] inner_tag_r[2];
  logic [7:0] raw_status_r[2];
  logic [3:0] received_tag_r[2];
  logic [7:0] reason_r[2];
  logic done_r[2], status_done_r[2];
  logic invalidate_pending_r, embedding_pending_r;
  logic [18:0] write_count_r, read_count_r, response_count_r;
  logic [2:0] read_pipe_r;
  logic [31:0] data_bytes[2], scale_base[2], scale_bytes[2];
  logic [31:0] data_bytes_calc[2], scale_base_calc[2], scale_bytes_calc[2];
  logic [32:0] local_end[2], ddr_end[2];
  logic [7:0] check_error[2];
  logic [1:0] selected_component[2];
  logic [31:0] selected_epoch[2];
  logic in_data[2], in_scale[2], in_rope[2], in_static[2];
  logic [1:0] offer_r;
  logic [1:0] inner_valid, inner_ready, inner_sts_valid, inner_sts_error, inner_fault;
  logic [7:0] inner_sts_code[2], inner_sts_raw[2];
  logic [3:0] inner_sts_bank[2], inner_sts_tag[2], inner_sts_received[2];
  logic [71:0] vendor_cmd[2];
  logic [1:0] vendor_valid, vendor_buffer_valid_r, vendor_sent_r;
  logic [71:0] vendor_buffer_r[2];
  logic [7:0] mapped_status[2];
  logic [1:0] engine_status_ready;
  logic engine_mm_ready, mm_span_bad, mm_take, mm_bad_take;
  logic wr_req[16], wr_grant[16], mm_start[16], mm_done[16], mm_abort[16];
  logic [22:0] mm_offset[16];
  logic [127:0] mm_data[16];
  logic [15:0] mm_keep[16];
  logic mm_valid[16], mm_ready[16], mm_last[16];
  logic rd_req[16], rd_grant[16], sm_start[16], sm_done[16], sm_abort[16];
  logic [22:0] sm_offset[16], sm_btt[16];
  logic [127:0] sm_data[16];
  logic [15:0] sm_keep[16];
  logic sm_valid[16], sm_ready[16], sm_last[16];
  logic adapter_mm_done, adapter_mm_ready, adapter_mm_write;
  logic [18:0] adapter_mm_addr;
  logic [127:0] adapter_mm_data;
  logic [15:0] adapter_mm_strb;
  logic adapter_sm_done, adapter_sm_enb, adapter_sm_read, adapter_sm_valid, adapter_sm_last;
  logic [18:0] adapter_sm_addr;
  logic [127:0] adapter_sm_data;
  logic [15:0] adapter_sm_keep;
  localparam logic [511:0] CAPACITIES = {
    32'd295040,32'd18528,32'd295008,32'd98304,32'd36864,32'd589824,
    32'd196672,32'd196640,32'd6016,32'd12288,32'd36864,32'd36864,
    32'd295424,32'd36864,32'd36864,32'd36864};

  // Each profile has disjoint configured payload and padded scale extents.
  // Controller validation of descriptor shape precedes this boundary.
  always @* begin
    for (integer d=0;d<2;d=d+1) begin
      data_bytes_calc[d]=0; scale_base_calc[d]=0; scale_bytes_calc[d]=0;
      case(profile_r[d])
        1,2,3,7,9,19: data_bytes_calc[d]=32'(rows_r[d])*1152;
        8,10: data_bytes_calc[d]=32'(rows_r[d])*384;
        13,15,18: data_bytes_calc[d]=32'(rows_r[d])*3072;
        16,17: data_bytes_calc[d]=32'(rows_r[d])*18*((32'(cols_r[d])+15)&32'hfffffff0);
        20: data_bytes_calc[d]=98304;
        5: data_bytes_calc[d]=1152;
        4: begin
          data_bytes_calc[d]=32'(rows_r[d])*32'(cols_r[d]);
          scale_base_calc[d]=294912; scale_bytes_calc[d]=(((32'(rows_r[d])+15)>>4)*4+15)&32'hfffffff0;
        end
        6: begin data_bytes_calc[d]=32'(rows_r[d])*576; scale_base_calc[d]=294912; scale_bytes_calc[d]=32'(rows_r[d])*16; end
        21: begin
          data_bytes_calc[d]=32'(rows_r[d])*32'(cols_r[d]); scale_base_calc[d]=294912;
          scale_bytes_calc[d]=(((32'(rows_r[d])+15)>>4)*4+15)&32'hfffffff0;
        end
        22: begin
          data_bytes_calc[d]=32'(rows_r[d])*9*((32'(cols_r[d])+15)&32'hfffffff0); scale_base_calc[d]=294912;
          scale_bytes_calc[d]=(9*((32'(rows_r[d])+15)>>4)*4+15)&32'hfffffff0;
        end
        23: begin
          data_bytes_calc[d]=32'(rows_r[d])*576; scale_base_calc[d]=18432;
          scale_bytes_calc[d]=(9*((32'(rows_r[d])+15)>>4)*4+15)&32'hfffffff0;
        end
        12,14: begin data_bytes_calc[d]=32'(rows_r[d])*192; scale_base_calc[d]=196608; scale_bytes_calc[d]=(profile_r[d]==12)?16:48; end
        11: data_bytes_calc[d]=32'(rope_rows_r[d])*128;
        default: data_bytes_calc[d]=0;
      endcase
      local_end[d]={1'b0,payload_r[d][111:80]}+{10'd0,payload_r[d][79:57]};
      ddr_end[d]={1'b0,payload_r[d][56:25]}+{10'd0,payload_r[d][79:57]};
      in_data[d]=(payload_r[d][111:80]<data_bytes[d]) && (local_end[d]<={1'b0,data_bytes[d]});
      in_scale[d]=(scale_bytes[d]!=0)&&(payload_r[d][111:80]>=scale_base[d]) &&
                   (local_end[d]<=({1'b0,scale_base[d]}+{1'b0,scale_bytes[d]}));
      in_rope[d]=(bank_r[d]==7)&&(profile_r[d]==11)&&in_data[d];
      in_static[d]=(bank_r[d]==7)&&(profile_r[d]==11)&&(payload_r[d][111:80]>=4096)&&(local_end[d]<=6016);
      selected_component[d]=(bank_r[d]!=7)?2'd0:((payload_r[d][111:80]>=4096)?2'd2:2'd1);
      selected_epoch[d]=(bank_r[d]!=7)?gen_r[d]:((payload_r[d][111:80]>=4096)?static_gen_r[d]:rope_gen_r[d]);
      check_error[d]=0;
      if(!tuple_ok_r[d] || !owner_ok_r[d]) check_error[d]=8'h07;
      else if(!present_r[d] || gen_r[d]==0 || (data_bytes[d]==0 && !(bank_r[d]==7 && profile_r[d]==11 && selected_component[d]==2))) check_error[d]=8'h04;
      else if(payload_r[d][79:57]==0 || payload_r[d][60:57]!=0 || payload_r[d][83:80]!=0 || payload_r[d][28:25]!=0 ||
              ddr_end[d][32] || local_end[d]> {1'b0,CAPACITIES[bank_r[d]*32+:32]} ||
              !(in_data[d]||in_scale[d]||in_static[d])) check_error[d]=8'h02;
      else if(payload_r[d][24:0]!=0 && !(d==0 && bank_r[d]==3 && profile_r[d]==6 &&
              payload_r[d][0] && payload_r[d][24:3]==0 && payload_r[d][79:57]==16 && in_scale[d])) check_error[d]=8'h02;
      else if(bank_r[d]==7 && (selected_epoch[d]==0 || gen_r[d]!=((rope_gen_r[d]>static_gen_r[d])?rope_gen_r[d]:static_gen_r[d]))) check_error[d]=8'h04;
      else if((profile_r[d]==12 || profile_r[d]==14) && layer_r[d]>=30) check_error[d]=8'h04;
      else if((profile_r[d]==16 || profile_r[d]==17 || profile_r[d]==22) &&
              (16'(position_r[d])+16'(rows_r[d])>cols_r[d] || layer_r[d]!=0)) check_error[d]=8'h04;
      else if(d==1) begin
        if(bank_r[d]==7) begin
          if((in_rope[d]&&!rope_valid_r[d]) || (in_static[d]&&!static_valid_r[d])) check_error[d]=8'h03;
        end else if(!data_valid_r[d] || (scale_bytes[d]!=0&&!scale_valid_r[d]) ||
          (profile_r[d]==6 && ((lane_valid_r[d] & (32'hffffffff >> (32-rows_r[d]))) != (32'hffffffff >> (32-rows_r[d]))))) check_error[d]=8'h03;
      end
    end
  end

  assign mm_span_bad = (s_axis_mm2s_tkeep!=16'hffff) ||
       (write_count_r>=payload_r[0][79:61]) ||
       (s_axis_mm2s_tlast != (write_count_r+19'd1==payload_r[0][79:61]));
  // Never present a malformed beat to the passthrough converter/native writer.
  assign s_axis_mm2s_tready = engine_mm_ready && !faulted[0];
  // Exactly one status per completed command; retain the outer response independently
  // of any late duplicate offered by the transport after success was captured.
  assign s_axis_mm2s_sts_tready=engine_status_ready[0]&&!status_done_r[0];
  assign s_axis_s2mm_sts_tready=engine_status_ready[1]&&!status_done_r[1];
  assign mm_take=s_axis_mm2s_tvalid && s_axis_mm2s_tready;
  assign mm_bad_take=mm_take&&mm_span_bad;
  assign mm2s_wr_valid=adapter_mm_write && !faulted[0];
  assign mm2s_wr_bank=bank_r[0];
  assign mm2s_wr_word_address=adapter_mm_addr;
  assign mm2s_wr_data=adapter_mm_data;
  assign mm2s_wr_strb=adapter_mm_strb;
  assign mm2s_wr_transaction_id=txn_r[0];
  assign mm2s_wr_generation=epoch_r[0];
  assign mm2s_wr_role=5'd1;
  assign s2mm_rd_valid=adapter_sm_read;
  assign s2mm_rd_bank=bank_r[1];
  assign s2mm_rd_word_address=adapter_sm_addr;
  assign embedding_valid=embedding_pending_r;
  assign embedding_transaction_id=txn_r[0];
  assign embedding_role=5'd1;
  assign embedding_generation=epoch_r[0];
  assign embedding_row=payload_r[0][88:84]; // (offset-294912)/16; base is 32-row aligned.
  assign embedding_lane=payload_r[0][2:1];
  assign invalidate_valid=invalidate_pending_r;
  assign invalidate_transaction_id=txn_r[0];
  assign invalidate_role=5'd1;
  assign invalidate_bank=bank_r[0];
  assign invalidate_generation=epoch_r[0];
  assign invalidate_component=component_r[0];

  always @* begin
    for(integer d=0;d<2;d=d+1) begin
      cmd_ready[d]=resetn&&enable_new_commands&&!faulted[d]&&(state[d]==IDLE)&&bank_ready[cmd_bank_ids[d*12+:4]];
      inner_valid[d]=offer_r[d]; // An offered request is never withdrawn on a later fault.
      resp_valid[d]=(state[d]==RESPONSE);
      resp_transaction_id[d*32+:32]=txn_r[d];
      resp_used_bank_mask[d*3+:3]=3'b001;
      resp_used_bank_count[d*2+:2]=2'd1;
      resp_bank_ids[d*12+:12]={8'd0,bank_r[d]};
      resp_generations[d*96+:96]={64'd0,gen_r[d]};
      resp_error_code[d*8+:8]=clean_error_r[d];
      busy[d]=(state[d]!=IDLE);
      fault_reason[d*8+:8]=reason_r[d]; fault_bank[d*4+:4]=bank_r[d];
      fault_transaction_id[d*32+:32]=txn_r[d];
      fault_raw_status[d*8+:8]=raw_status_r[d];
      fault_received_tag[d*4+:4]=received_tag_r[d];
      fault_internal_tag[d*4+:4]=inner_tag_r[d];
    end
    for(integer i=0;i<16;i=i+1) begin
      wr_grant[i]=(bank_r[0]==4'(i))&&bank_ready[i]&&wr_req[i]&&vendor_sent_r[0]&&!faulted[0];
      rd_grant[i]=(bank_r[1]==4'(i))&&bank_ready[i]&&rd_req[i]&&vendor_sent_r[1]&&!faulted[1];
      mm_done[i]=(bank_r[0]==4'(i))&&adapter_mm_done;
      mm_ready[i]=(bank_r[0]==4'(i))&&adapter_mm_ready;
      sm_done[i]=(bank_r[1]==4'(i))&&adapter_sm_done;
      sm_data[i]=adapter_sm_data; sm_keep[i]=adapter_sm_keep;
      sm_valid[i]=(bank_r[1]==4'(i))&&adapter_sm_valid;
      sm_last[i]=adapter_sm_last;
    end
    mapped_status[0]={s_axis_mm2s_sts_tdata[7:4],
       ((vendor_sent_r[0] && s_axis_mm2s_sts_tdata[3:0]==bank_r[0])?inner_tag_r[0]:(inner_tag_r[0]^4'd1))};
    mapped_status[1]={s_axis_s2mm_sts_tdata[7:4],
       ((vendor_sent_r[1] && s_axis_s2mm_sts_tdata[3:0]==bank_r[1])?inner_tag_r[1]:(inner_tag_r[1]^4'd1))};
  end
  assign m_axis_mm2s_cmd_tdata={vendor_buffer_r[0][71:68],bank_r[0],vendor_buffer_r[0][63:0]};
  assign m_axis_mm2s_cmd_tvalid=vendor_buffer_valid_r[0];
  assign m_axis_s2mm_cmd_tdata={vendor_buffer_r[1][71:68],bank_r[1],vendor_buffer_r[1][63:0]};
  assign m_axis_s2mm_cmd_tvalid=vendor_buffer_valid_r[1];

  always_ff @(posedge clk) begin
    if(!resetn) begin
      offer_r<=0; vendor_buffer_valid_r<=0; vendor_sent_r<=0; faulted<=0; invalidate_pending_r<=0; embedding_pending_r<=0;
      write_count_r<=0; read_count_r<=0; response_count_r<=0; read_pipe_r<=0;
      for(integer d=0;d<2;d=d+1) begin
        data_bytes[d]<=0; scale_base[d]<=0; scale_bytes[d]<=0; state[d]<=IDLE; bank_r[d]<=0; txn_r[d]<=0; gen_r[d]<=0; epoch_r[d]<=0;
        payload_r[d]<=0; profile_r[d]<=0; rows_r[d]<=0; cols_r[d]<=0; position_r[d]<=0; layer_r[d]<=0;
        lane_valid_r[d]<=0; present_r[d]<=0; data_valid_r[d]<=0; scale_valid_r[d]<=0;
        owner_ok_r[d]<=0; tuple_ok_r[d]<=0; rope_rows_r[d]<=0; rope_valid_r[d]<=0; static_valid_r[d]<=0;
        rope_gen_r[d]<=0; static_gen_r[d]<=0; component_r[d]<=0; clean_error_r[d]<=0;
        vendor_buffer_r[d]<=0; inner_tag_r[d]<=0; raw_status_r[d]<=0; received_tag_r[d]<=0; reason_r[d]<=0;
        done_r[d]<=0; status_done_r[d]<=0;
      end
    end else begin
      read_pipe_r<={read_pipe_r[1:0],s2mm_rd_valid&&s2mm_rd_ready};
      if(s2mm_rd_valid&&s2mm_rd_ready) read_count_r<=read_count_r+1'b1;
      if(s2mm_rd_resp_valid) response_count_r<=response_count_r+1'b1;
      if(mm2s_wr_valid && mm2s_wr_commit) write_count_r<=write_count_r+1'b1;
      if(invalidate_pending_r&&invalidate_ready) begin
        invalidate_pending_r<=0;
        if(invalidate_error_code!=0) begin faulted[0]<=1; reason_r[0]<=8'h62; state[0]<=FAULT; end
      end
      if(embedding_pending_r&&embedding_ready) begin
        embedding_pending_r<=0;
        if(embedding_error_code!=0) begin faulted[0]<=1; reason_r[0]<=8'h62; state[0]<=FAULT; invalidate_pending_r<=1; end
      end
      for(integer d=0;d<2;d=d+1) begin
        if(state[d]==IDLE && cmd_valid[d]&&cmd_ready[d]) begin
          state[d]<=CHECK; bank_r[d]<=cmd_bank_ids[d*12+:4]; txn_r[d]<=cmd_transaction_id[d*32+:32];
          gen_r[d]<=cmd_generations[d*96+:32]; payload_r[d]<=cmd_payload[d*112+:112];
          profile_r[d]<=cmd_profile[d*5+:5]; rows_r[d]<=cmd_rows[d*11+:11]; cols_r[d]<=cmd_cols[d*16+:16];
          position_r[d]<=cmd_position[d*10+:10]; layer_r[d]<=cmd_layer[d*5+:5];
          lane_valid_r[d]<=cmd_embedding_lane_valid[d*32+:32]; present_r[d]<=cmd_desc_present[d];
          data_valid_r[d]<=cmd_data_valid[d]; scale_valid_r[d]<=cmd_scale_valid[d];
          owner_ok_r[d]<=(!cmd_desc_busy[d] && cmd_desc_owner[d*5+:5]==0) ||
             (cmd_desc_busy[d] && cmd_desc_owner[d*5+:5]==5'(d+1));
          tuple_ok_r[d]<=(cmd_opcode[d*4+:4]==4'(d+1))&&(cmd_bank_ids[d*12+4+:8]==0)&&(cmd_generations[d*96+32+:64]==0);
          rope_rows_r[d]<=bank_b7_rope_rows; rope_valid_r[d]<=bank_b7_rope_valid; static_valid_r[d]<=bank_b7_static_valid;
          rope_gen_r[d]<=bank_b7_rope_generation; static_gen_r[d]<=bank_b7_static_generation;
          done_r[d]<=0; status_done_r[d]<=0; clean_error_r[d]<=0; vendor_sent_r[d]<=0;
          if(d==0) write_count_r<=0;
          else begin read_count_r<=0; response_count_r<=0; read_pipe_r<=0; end
        end
        if(state[d]==CHECK) begin
          epoch_r[d]<=selected_epoch[d]; component_r[d]<=selected_component[d];
          data_bytes[d]<=data_bytes_calc[d];scale_base[d]<=scale_base_calc[d];scale_bytes[d]<=scale_bytes_calc[d];
          state[d]<=VALIDATE;
        end
        if(state[d]==VALIDATE) begin
          clean_error_r[d]<=check_error[d];
          if(check_error[d]!=0) begin
            state[d]<=BARRIER;
            if(d==0 && present_r[d] && gen_r[d]!=0 && owner_ok_r[d] && selected_epoch[d]!=0) invalidate_pending_r<=1;
          end else begin state[d]<=OFFER; offer_r[d]<=1; end
        end
        if(offer_r[d] && inner_ready[d]) begin
          offer_r[d]<=0; if(!faulted[d]) state[d]<=ACTIVE;
        end
        if(vendor_valid[d] && !vendor_buffer_valid_r[d]) begin
          vendor_buffer_r[d]<=vendor_cmd[d]; vendor_buffer_valid_r[d]<=1;
          inner_tag_r[d]<=vendor_cmd[d][67:64];
        end
        if(vendor_buffer_valid_r[d] && ((d==0)?m_axis_mm2s_cmd_tready:m_axis_s2mm_cmd_tready)) begin
          vendor_buffer_valid_r[d]<=0; vendor_sent_r[d]<=1;
        end
        if(((d==0)?(s_axis_mm2s_sts_tvalid&&s_axis_mm2s_sts_tready):(s_axis_s2mm_sts_tvalid&&s_axis_s2mm_sts_tready))) begin
          raw_status_r[d]<=(d==0)?s_axis_mm2s_sts_tdata:s_axis_s2mm_sts_tdata;
          received_tag_r[d]<=(d==0)?s_axis_mm2s_sts_tdata[3:0]:s_axis_s2mm_sts_tdata[3:0];
        end
        if((d==0)?adapter_mm_done:adapter_sm_done) done_r[d]<=1;
        if(inner_sts_valid[d]) begin
          if(inner_sts_error[d] || inner_fault[d] || inner_sts_bank[d]!=bank_r[d] ||
             inner_sts_tag[d]!=inner_tag_r[d] || inner_sts_received[d]!=inner_sts_raw[d][3:0]) begin
            faulted[d]<=1; reason_r[d]<=inner_sts_code[d]; state[d]<=FAULT;
            if(d==0) invalidate_pending_r<=1;
          end else begin
            status_done_r[d]<=1; state[d]<=BARRIER;
            if(d==0 && payload_r[0][0] && profile_r[0]==6) embedding_pending_r<=1;
          end
        end
        if(state[d]==BARRIER && bank_quiescent[bank_r[d]] && !wr_pending[bank_r[d]] && !coverage_pending[bank_r[d]] &&
           ((d==0)?(!invalidate_pending_r&&!embedding_pending_r):((read_count_r==response_count_r)&&(read_pipe_r==0)&&!adapter_sm_enb)) &&
           ((clean_error_r[d]!=0)||(status_done_r[d]&&done_r[d]&&vendor_sent_r[d]&&
             ((d==0)?(write_count_r==payload_r[d][79:61]):(read_count_r==payload_r[d][79:61]))))) state[d]<=RESPONSE;
        if(state[d]==RESPONSE && resp_ready[d]) state[d]<=IDLE;
      end
      if(mm_bad_take) begin faulted[0]<=1; reason_r[0]<=8'h60; state[0]<=FAULT; invalidate_pending_r<=1; end
      if(mm2s_wr_valid && (!mm2s_wr_ready || !mm2s_wr_commit)) begin
        faulted[0]<=1; reason_r[0]<=8'h61; state[0]<=FAULT; invalidate_pending_r<=1;
      end
      if((s2mm_rd_valid&&!s2mm_rd_ready) || (s2mm_rd_resp_valid!=read_pipe_r[2])) begin
        faulted[1]<=1; reason_r[1]<=8'h61; state[1]<=FAULT;
      end
    end
  end

  datamover_engine #(.DMA_DATA_WIDTH(128),.BANK_NUM(16),.BANK_WIDTH(4),
    .BANK_WORD_BYTES({16{32'd16}}),.BANK_CAPACITY_BYTES(CAPACITIES)) u_datamover (
    .aclk(clk),
    .aresetn(resetn),
    .s_ctrl_mm2s_pause(1'b0),
    .s_ctrl_mm2s_abort(faulted[0]),
    .m_ctrl_mm2s_sts_ready(1'b1),
    .m_ctrl_mm2s_faulted(inner_fault[0]),
    .m_ctrl_mm2s_sts_tag(inner_sts_tag[0]),
    .m_ctrl_mm2s_sts_received_tag(inner_sts_received[0]),
    .m_ctrl_mm2s_sts_raw_status(inner_sts_raw[0]),
    .s_ctrl_mm2s_cmd_valid(inner_valid[0]),
    .s_ctrl_mm2s_cmd_ready(inner_ready[0]),
    .s_ctrl_mm2s_cmd_addr(payload_r[0][56:25]),
    .s_ctrl_mm2s_cmd_btt(payload_r[0][79:57]),
    .s_ctrl_mm2s_cmd_offset(payload_r[0][102:80]),
    .s_ctrl_mm2s_cmd_bank(bank_r[0]),
    .m_ctrl_mm2s_sts_valid(inner_sts_valid[0]),
    .m_ctrl_mm2s_sts_error(inner_sts_error[0]),
    .m_ctrl_mm2s_sts_error_code(inner_sts_code[0]),
    .m_ctrl_mm2s_sts_bank(inner_sts_bank[0]),
    .s_ctrl_s2mm_pause(1'b0),
    .s_ctrl_s2mm_abort(faulted[1]),
    .m_ctrl_s2mm_sts_ready(1'b1),
    .m_ctrl_s2mm_faulted(inner_fault[1]),
    .m_ctrl_s2mm_sts_tag(inner_sts_tag[1]),
    .m_ctrl_s2mm_sts_received_tag(inner_sts_received[1]),
    .m_ctrl_s2mm_sts_raw_status(inner_sts_raw[1]),
    .s_ctrl_s2mm_cmd_valid(inner_valid[1]),
    .s_ctrl_s2mm_cmd_ready(inner_ready[1]),
    .s_ctrl_s2mm_cmd_addr(payload_r[1][56:25]),
    .s_ctrl_s2mm_cmd_btt(payload_r[1][79:57]),
    .s_ctrl_s2mm_cmd_offset(payload_r[1][102:80]),
    .s_ctrl_s2mm_cmd_bank(bank_r[1]),
    .m_ctrl_s2mm_sts_valid(inner_sts_valid[1]),
    .m_ctrl_s2mm_sts_error(inner_sts_error[1]),
    .m_ctrl_s2mm_sts_error_code(inner_sts_code[1]),
    .m_ctrl_s2mm_sts_bank(inner_sts_bank[1]),
    .m_axis_mm2s_cmd_tdata(vendor_cmd[0]),
    .m_axis_mm2s_cmd_tvalid(vendor_valid[0]),
    .m_axis_mm2s_cmd_tready(!vendor_buffer_valid_r[0]),
    .s_axis_mm2s_tdata(s_axis_mm2s_tdata),
    .s_axis_mm2s_tkeep(s_axis_mm2s_tkeep),
    .s_axis_mm2s_tvalid(s_axis_mm2s_tvalid && !mm_span_bad && !faulted[0]),
    .s_axis_mm2s_tready(engine_mm_ready),
    .s_axis_mm2s_tlast(s_axis_mm2s_tlast),
    .s_axis_mm2s_sts_tdata(mapped_status[0]),
    .s_axis_mm2s_sts_tkeep(s_axis_mm2s_sts_tkeep),
    .s_axis_mm2s_sts_tvalid(s_axis_mm2s_sts_tvalid&&!status_done_r[0]),
    .s_axis_mm2s_sts_tready(engine_status_ready[0]),
    .s_axis_mm2s_sts_tlast(s_axis_mm2s_sts_tlast),
    .m_axis_s2mm_cmd_tdata(vendor_cmd[1]),
    .m_axis_s2mm_cmd_tvalid(vendor_valid[1]),
    .m_axis_s2mm_cmd_tready(!vendor_buffer_valid_r[1]),
    .m_axis_s2mm_tdata(m_axis_s2mm_tdata),
    .m_axis_s2mm_tkeep(m_axis_s2mm_tkeep),
    .m_axis_s2mm_tvalid(m_axis_s2mm_tvalid),
    .m_axis_s2mm_tready(m_axis_s2mm_tready),
    .m_axis_s2mm_tlast(m_axis_s2mm_tlast),
    .s_axis_s2mm_sts_tdata(mapped_status[1]),
    .s_axis_s2mm_sts_tkeep(s_axis_s2mm_sts_tkeep),
    .s_axis_s2mm_sts_tvalid(s_axis_s2mm_sts_tvalid&&!status_done_r[1]),
    .s_axis_s2mm_sts_tready(engine_status_ready[1]),
    .s_axis_s2mm_sts_tlast(s_axis_s2mm_sts_tlast),
    .m_ctrl_bank_wr_req(wr_req),
    .m_ctrl_bank_wr_grant(wr_grant),
    .m_ctrl_mm2s_adapter_start(mm_start),
    .m_ctrl_mm2s_adapter_done(mm_done),
    .m_ctrl_mm2s_adapter_abort(mm_abort),
    .m_ctrl_mm2s_adapter_offset(mm_offset),
    .m_axis_mm2s_tdata(mm_data),
    .m_axis_mm2s_tkeep(mm_keep),
    .m_axis_mm2s_tvalid(mm_valid),
    .m_axis_mm2s_tready(mm_ready),
    .m_axis_mm2s_tlast(mm_last),
    .m_ctrl_bank_rd_req(rd_req),
    .m_ctrl_bank_rd_grant(rd_grant),
    .m_ctrl_s2mm_adapter_start(sm_start),
    .m_ctrl_s2mm_adapter_done(sm_done),
    .m_ctrl_s2mm_adapter_abort(sm_abort),
    .m_ctrl_s2mm_adapter_btt(sm_btt),
    .m_ctrl_s2mm_adapter_offset(sm_offset),
    .s_axis_s2mm_tdata(sm_data),
    .s_axis_s2mm_tkeep(sm_keep),
    .s_axis_s2mm_tvalid(sm_valid),
    .s_axis_s2mm_tready(sm_ready),
    .s_axis_s2mm_tlast(sm_last)
  );

  mm2s_adapter #(.MM2S_DATA_WIDTH(128),.BANK_ADDRA_WIDTH(19),.BANK_DINA_WIDTH(128)) u_mm2s_adapter (
    .aclk(clk),.aresetn(resetn),.s_ctrl_mm2s_adapter_start(mm_start[bank_r[0]]),
    .s_ctrl_mm2s_adapter_done(adapter_mm_done),.s_ctrl_mm2s_adapter_abort(mm_abort[bank_r[0]]||faulted[0]),
    .s_ctrl_mm2s_adapter_offset(mm_offset[bank_r[0]]),.s_axis_mm2s_tdata(mm_data[bank_r[0]]),
    .s_axis_mm2s_tkeep(mm_keep[bank_r[0]]),.s_axis_mm2s_tvalid(mm_valid[bank_r[0]]),
    .s_axis_mm2s_tready(adapter_mm_ready),.s_axis_mm2s_tlast(mm_last[bank_r[0]]),
    .bank_ena(adapter_mm_write),.bank_addra(adapter_mm_addr),.bank_dina(adapter_mm_data),.bank_wea(adapter_mm_strb));
  s2mm_adapter #(.S2MM_DATA_WIDTH(128),.BANK_ADDRB_WIDTH(19),.BANK_DOUTB_WIDTH(128),.BANK_READ_LAT(3)) u_s2mm_adapter (
    .aclk(clk),.aresetn(resetn),.s_ctrl_s2mm_adapter_start(sm_start[bank_r[1]]),
    .s_ctrl_s2mm_adapter_done(adapter_sm_done),.s_ctrl_s2mm_adapter_abort(sm_abort[bank_r[1]]||faulted[1]),
    .s_ctrl_s2mm_adapter_offset(sm_offset[bank_r[1]]),.s_ctrl_s2mm_adapter_btt(sm_btt[bank_r[1]]),
    .m_axis_s2mm_tdata(adapter_sm_data),.m_axis_s2mm_tkeep(adapter_sm_keep),
    .m_axis_s2mm_tvalid(adapter_sm_valid),.m_axis_s2mm_tready(sm_ready[bank_r[1]]),
    .m_axis_s2mm_tlast(adapter_sm_last),.bank_enb(adapter_sm_enb),.bank_read_issue(adapter_sm_read),
    .bank_addrb(adapter_sm_addr),.bank_doutb(s2mm_rd_data));
endmodule
