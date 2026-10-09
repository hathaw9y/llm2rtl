`timescale 1ns/1ps
module smollm2_bank_controller (
  input logic clk,
  input logic resetn,
  output logic [15:0] bank_busy,
  output logic [79:0] bank_owner_port,
  output logic [15:0] bank_desc_present,
  output logic [79:0] bank_profiles,
  output logic [175:0] bank_rows,
  output logic [255:0] bank_cols,
  output logic [159:0] bank_positions,
  output logic [79:0] bank_layers,
  output logic [511:0] bank_generations,
  output logic [15:0] bank_data_valid,
  output logic [15:0] bank_scale_valid,
  output logic bank_b7_static_valid,
  output logic bank_b7_rope_valid,
  output logic [63:0] bank_embedding_lanes,
  output logic [31:0] bank_embedding_lane_valid,
  input logic acquire_valid,
  input logic [31:0] acquire_transaction_id,
  input logic [2:0] acquire_used_bank_mask,
  input logic [11:0] acquire_bank_ids,
  input logic [14:0] acquire_roles,
  input logic [95:0] acquire_generations,
  output logic acquire_ready,
  output logic [7:0] acquire_error_code,
  input logic release_valid,
  input logic [31:0] release_transaction_id,
  input logic [2:0] release_used_bank_mask,
  input logic [11:0] release_bank_ids,
  input logic [14:0] release_roles,
  input logic [95:0] release_generations,
  output logic release_ready,
  output logic [7:0] release_error_code,
  input logic cfg_valid,
  input logic [31:0] cfg_transaction_id,
  input logic [3:0] cfg_bank,
  input logic [4:0] cfg_profile,
  input logic [10:0] cfg_rows,
  input logic [15:0] cfg_cols,
  input logic [9:0] cfg_position,
  input logic [4:0] cfg_layer,
  input logic [1:0] cfg_component,
  input logic [31:0] cfg_generation,
  input logic cfg_resp_ready,
  output logic cfg_ready,
  output logic cfg_resp_valid,
  output logic [31:0] cfg_resp_transaction_id,
  output logic [7:0] cfg_resp_error_code,
  input logic producer_valid,
  input logic [31:0] producer_transaction_id,
  input logic [4:0] producer_role,
  input logic [3:0] producer_bank,
  input logic [31:0] producer_accepted_generation,
  input logic [31:0] producer_generation,
  input logic [4:0] producer_profile,
  input logic [10:0] producer_rows,
  input logic [15:0] producer_cols,
  input logic [9:0] producer_position,
  input logic [4:0] producer_layer,
  output logic producer_ready,
  output logic [7:0] producer_error_code,
  input logic [1:0] invalidate_component,
  input logic invalidate_valid,
  input logic [31:0] invalidate_transaction_id,
  input logic [4:0] invalidate_role,
  input logic [3:0] invalidate_bank,
  input logic [31:0] invalidate_generation,
  output logic invalidate_ready,
  output logic [7:0] invalidate_error_code,
  input logic coverage_valid,
  input logic [3:0] coverage_bank,
  input logic [1:0] coverage_component,
  input logic [31:0] coverage_generation,
  input logic [31:0] coverage_transaction_id,
  input logic [4:0] coverage_role,
  input logic coverage_data_complete,
  input logic coverage_scale_complete,
  output logic coverage_ready,
  output logic [7:0] coverage_error_code,
  input logic embedding_valid,
  input logic [31:0] embedding_transaction_id,
  input logic [4:0] embedding_role,
  input logic [31:0] embedding_generation,
  input logic [4:0] embedding_row,
  input logic [1:0] embedding_lane,
  output logic embedding_ready,
  output logic [7:0] embedding_error_code
);

  // Priority per bank: invalidate, producer, config, embedding, coverage,
  // release, acquire. Disjoint ownership events can commit together.
  logic [31:0] owner_txn_r[16], owner_gen_r[16];
  logic [31:0] rope_gen_r, static_gen_r;
  logic [15:0] invalid_r;
  logic rope_invalid_r, static_invalid_r;
  logic [0:15] core_acq,core_rel,core_busy;
  logic [0:15][4:0] core_ap,core_rp,core_owner;
  logic core_error; logic [2:0] core_error_code;
  logic [15:0] acq_mask_w,rel_mask_w,meta_mask_w;
  logic acq_bad_w,rel_bad_w;
  logic cfg_fire_w,prod_fire_w,inv_fire_w,cov_fire_w,emb_fire_w;
  function automatic logic shape_ok(input logic[3:0] b,input logic[4:0] p,
      input logic[10:0] r,input logic[15:0] c,input logic[9:0] pos,
      input logic[4:0] layer,input logic[1:0] component);
    logic allowed,shape; logic[11:0] endpos;
    begin
      allowed=0; shape=0; endpos={2'b0,pos}+{1'b0,r};
      case(b)
        0:allowed=p==1;1:allowed=p==2;2:allowed=p==3;
        3:allowed=p==4||p==5||p==6;4:allowed=p==7;
        5:allowed=p==8||p==9;6:allowed=p==10;7:allowed=p==11;
        8:allowed=p==12||p==13;9:allowed=p==14||p==15;
        10:allowed=p==16||p==17||p==18;11:allowed=p==19;
        12:allowed=p==20;13:allowed=p==21||p==22;
        14:allowed=p==23;15:allowed=p==4;
        default:allowed=0;
      endcase
      case(p)
        4:shape=r>=1&&r<=192&&(c==576||c==1536);
        5:shape=r==1&&c==576;
        11:shape=c==64&&((component==2&&r==30&&pos==0)||
                    (component!=2&&r>=1&&r<=32&&endpos<=1024));
        12,14:shape=r>=1&&r<=1024&&c==192&&layer<30;
        16,17,22:shape=r>=1&&r<=32&&c>=1&&c<=1024&&endpos<={1'b0,c[10:0]};
        21:shape=r>=1&&r<=32&&(c==576||c==1536);
        20:shape=r==1&&c==49152;
        8,10:shape=r>=1&&r<=32&&c==192;
        13,15,18:shape=r>=1&&r<=32&&c==1536;
        default:shape=r>=1&&r<=32&&c==576;
      endcase
      // Each allowed profile's bounded shape fits its pinned bank allocation,
      // including padded 16-byte scales and 9-head padded probability rows.
      shape_ok=allowed&&shape&&(b==7?component<=2:component==0)&&
        ((p==11||p==16||p==17||p==22)||pos==0)&&
        ((p==12||p==14)||layer==0);
    end
  endfunction
  function automatic logic owned(input logic[3:0] b,input logic[31:0] txn,
                                  input logic[4:0] role);
    owned=bank_busy[b]&&bank_owner_port[b*5+:5]==role&&owner_txn_r[b]==txn;
  endfunction
  bank_ownership_table #(.BANK_NUM(16),.PORT_ROLE_WIDTH(5)) ownership (
    .aclk(clk),.aresetn(resetn),.acquire_valid(core_acq),.acquire_port(core_ap),
    .release_valid(core_rel),.release_port(core_rp),.bank_busy(core_busy),
    .bank_owner_port(core_owner),.ownership_error(core_error),
    .ownership_error_code(core_error_code));
`ifndef SYNTHESIS
  always_ff @(posedge clk) if(resetn&&core_error)
    $fatal(1,"wrapper issued invalid core ownership event: %0d",core_error_code);
`endif
  for(genvar g=0;g<16;g++) begin:flatten
    assign bank_busy[g]=core_busy[g];
    assign bank_owner_port[g*5+:5]=core_owner[g];
  end
  always_comb begin
    cfg_ready=!cfg_resp_valid||cfg_resp_ready;
    invalidate_ready=1; invalidate_error_code=0;
    if(!owned(invalidate_bank,invalidate_transaction_id,invalidate_role))
      invalidate_error_code=8'h07;
    if(invalidate_bank==7)begin
      case(invalidate_component)
        0:if(bank_generations[224+:32]!=invalidate_generation)invalidate_error_code=8'h07;
        1:if(rope_gen_r!=invalidate_generation)invalidate_error_code=8'h07;
        2:if(static_gen_r!=invalidate_generation)invalidate_error_code=8'h07;
        default:invalidate_error_code=8'h07;
      endcase
    end else if(invalidate_component!=0||
      bank_generations[invalidate_bank*32+:32]!=invalidate_generation)invalidate_error_code=8'h07;
    inv_fire_w=invalidate_valid&&invalidate_ready&&invalidate_error_code==0;
    producer_ready=!(invalidate_valid&&invalidate_bank==producer_bank);
    producer_error_code=0;
    if(!owned(producer_bank,producer_transaction_id,producer_role)||
      owner_gen_r[producer_bank]!=producer_accepted_generation||
      bank_generations[producer_bank*32+:32]!=producer_accepted_generation||
      producer_accepted_generation==32'hffffffff||
      producer_generation!=producer_accepted_generation+32'd1||
      !shape_ok(producer_bank,producer_profile,producer_rows,producer_cols,
                producer_position,producer_layer,0)) producer_error_code=8'h07;
    prod_fire_w=producer_valid&&producer_ready&&producer_error_code==0;
    cfg_fire_w=cfg_valid&&cfg_ready;
    embedding_ready=!(invalidate_valid&&invalidate_bank==3)&&
                     !(producer_valid&&producer_bank==3)&&!(cfg_valid&&cfg_bank==3);
    embedding_error_code=0;
    if(!owned(3,embedding_transaction_id,embedding_role)||bank_profiles[15+:5]!=6||
      bank_generations[96+:32]!=embedding_generation||invalid_r[3]||
      {6'b0,embedding_row}>=bank_rows[33+:11]) embedding_error_code=8'h07;
    emb_fire_w=embedding_valid&&embedding_ready&&embedding_error_code==0;
    coverage_ready=!(invalidate_valid&&invalidate_bank==coverage_bank)&&
                   !(producer_valid&&producer_bank==coverage_bank)&&
                   !(cfg_valid&&cfg_bank==coverage_bank)&&
                   !(embedding_valid&&coverage_bank==3);
    coverage_error_code=0;
    if(!owned(coverage_bank,coverage_transaction_id,coverage_role)||
      !bank_desc_present[coverage_bank]) coverage_error_code=8'h07;
    if(coverage_bank==7) begin
      if(coverage_component==1) begin
        if(coverage_generation!=rope_gen_r||rope_invalid_r) coverage_error_code=8'h07;
      end else if(coverage_component==2) begin
        if(coverage_generation!=static_gen_r||static_invalid_r) coverage_error_code=8'h07;
      end else coverage_error_code=8'h07;
    end else if(coverage_component!=0||invalid_r[coverage_bank]||
      coverage_generation!=bank_generations[coverage_bank*32+:32]) coverage_error_code=8'h07;
    cov_fire_w=coverage_valid&&coverage_ready&&coverage_error_code==0;
    meta_mask_w=0;
    if(invalidate_valid)meta_mask_w[invalidate_bank]=1;
    if(producer_valid)meta_mask_w[producer_bank]=1;
    if(cfg_valid&&cfg_ready)meta_mask_w[cfg_bank]=1;
    if(coverage_valid)meta_mask_w[coverage_bank]=1;
    if(embedding_valid)meta_mask_w[3]=1;
    acq_mask_w=0;rel_mask_w=0;acq_bad_w=acquire_used_bank_mask==0;
    rel_bad_w=release_used_bank_mask==0;
    acquire_ready=1;release_ready=1;
    for(int i=0;i<3;i++)begin
      if(acquire_used_bank_mask[i])begin
        if(acq_mask_w[acquire_bank_ids[i*4+:4]]||acquire_roles[i*5+:5]==0||
          acquire_roles[i*5+:5]>26||acquire_generations[i*32+:32]!=
          bank_generations[acquire_bank_ids[i*4+:4]*32+:32])acq_bad_w=1;
        acq_mask_w[acquire_bank_ids[i*4+:4]]=1;
        if(bank_busy[acquire_bank_ids[i*4+:4]])acquire_ready=0;
      end
      if(release_used_bank_mask[i])begin
        if(rel_mask_w[release_bank_ids[i*4+:4]]||
          !owned(release_bank_ids[i*4+:4],release_transaction_id,release_roles[i*5+:5])||
          owner_gen_r[release_bank_ids[i*4+:4]]!=release_generations[i*32+:32])rel_bad_w=1;
        rel_mask_w[release_bank_ids[i*4+:4]]=1;
      end
    end
    if(|(acq_mask_w&meta_mask_w))acquire_ready=0;
    if(|(rel_mask_w&meta_mask_w))release_ready=0;
    acquire_error_code=acq_bad_w?8'h07:0;
    if(acq_bad_w)acquire_ready=0;
    release_error_code=rel_bad_w?8'h07:0;
    core_acq=0;core_rel=0;core_ap=0;core_rp=0;
    for(int i=0;i<3;i++)begin
      if(acquire_used_bank_mask[i]&&acquire_valid&&acquire_ready)begin
        core_acq[acquire_bank_ids[i*4+:4]]=1;
        core_ap[acquire_bank_ids[i*4+:4]]=acquire_roles[i*5+:5];
      end
      if(release_used_bank_mask[i]&&release_valid&&release_ready&&!rel_bad_w)begin
        core_rel[release_bank_ids[i*4+:4]]=1;
        core_rp[release_bank_ids[i*4+:4]]=release_roles[i*5+:5];
      end
    end
  end

  always_ff @(posedge clk)begin
    if(!resetn)begin
      bank_desc_present<=0;bank_profiles<=0;bank_rows<=0;bank_cols<=0;
      bank_positions<=0;bank_layers<=0;bank_generations<=0;
      bank_data_valid<=0;bank_scale_valid<=0;bank_b7_static_valid<=0;
      bank_b7_rope_valid<=0;bank_embedding_lanes<=0;bank_embedding_lane_valid<=0;
      invalid_r<=0;rope_invalid_r<=0;static_invalid_r<=0;
      rope_gen_r<=0;static_gen_r<=0;cfg_resp_valid<=0;
      cfg_resp_transaction_id<=0;cfg_resp_error_code<=0;
      for(int k=0;k<16;k++)begin owner_txn_r[k]<=0;owner_gen_r[k]<=0;end
    end else begin
      if(cfg_resp_valid&&cfg_resp_ready)cfg_resp_valid<=0;
      for(int i=0;i<3;i++)if(acquire_used_bank_mask[i]&&core_acq[acquire_bank_ids[i*4+:4]])begin
        owner_txn_r[acquire_bank_ids[i*4+:4]]<=acquire_transaction_id;
        owner_gen_r[acquire_bank_ids[i*4+:4]]<=acquire_generations[i*32+:32];
      end
      if(cfg_fire_w)begin
        cfg_resp_valid<=1;cfg_resp_transaction_id<=cfg_transaction_id;
        cfg_resp_error_code<=8'h07;
        if(!bank_busy[cfg_bank]&&shape_ok(cfg_bank,cfg_profile,cfg_rows,cfg_cols,
          cfg_position,cfg_layer,cfg_component)&&cfg_generation!=0&&
          (cfg_bank==7?((cfg_component==2||cfg_generation>rope_gen_r)&&
                        (cfg_component==1||cfg_generation>static_gen_r)):
                        cfg_generation>bank_generations[cfg_bank*32+:32]))begin
          cfg_resp_error_code<=0;bank_desc_present[cfg_bank]<=1;
          bank_profiles[cfg_bank*5+:5]<=cfg_profile;
          if(cfg_bank!=7||cfg_component!=2||!bank_desc_present[7])begin
            bank_rows[cfg_bank*11+:11]<=cfg_rows;bank_cols[cfg_bank*16+:16]<=cfg_cols;
            bank_positions[cfg_bank*10+:10]<=cfg_position;bank_layers[cfg_bank*5+:5]<=cfg_layer;
          end
          if(cfg_bank==7)begin
            if(cfg_generation>bank_generations[224+:32])bank_generations[224+:32]<=cfg_generation;
            if(cfg_component!=2)begin rope_gen_r<=cfg_generation;bank_b7_rope_valid<=0;
              bank_data_valid[7]<=0;rope_invalid_r<=0;end
            if(cfg_component!=1)begin static_gen_r<=cfg_generation;bank_b7_static_valid<=0;
              bank_scale_valid[7]<=0;static_invalid_r<=0;end
          end else begin
            bank_generations[cfg_bank*32+:32]<=cfg_generation;
            bank_data_valid[cfg_bank]<=0;bank_scale_valid[cfg_bank]<=0;invalid_r[cfg_bank]<=0;
            if(cfg_bank==3)begin bank_embedding_lane_valid<=0;bank_embedding_lanes<=0;end
          end
        end
      end
      if(prod_fire_w)begin
        bank_desc_present[producer_bank]<=1;bank_profiles[producer_bank*5+:5]<=producer_profile;
        bank_rows[producer_bank*11+:11]<=producer_rows;bank_cols[producer_bank*16+:16]<=producer_cols;
        bank_positions[producer_bank*10+:10]<=producer_position;bank_layers[producer_bank*5+:5]<=producer_layer;
        bank_generations[producer_bank*32+:32]<=producer_generation;
        bank_data_valid[producer_bank]<=0;bank_scale_valid[producer_bank]<=0;invalid_r[producer_bank]<=0;
        if(producer_bank==3)begin bank_embedding_lane_valid<=0;bank_embedding_lanes<=0;end
        if(producer_bank==7)begin rope_gen_r<=producer_generation;static_gen_r<=producer_generation;
          bank_b7_rope_valid<=0;bank_b7_static_valid<=0;rope_invalid_r<=0;static_invalid_r<=0;end
      end
      if(cov_fire_w)begin
        if(coverage_bank==7)begin
          if(coverage_component==1)begin
            bank_b7_rope_valid<=bank_b7_rope_valid||coverage_data_complete;
            bank_data_valid[7]<=bank_data_valid[7]||coverage_data_complete;
          end else begin
            bank_b7_static_valid<=bank_b7_static_valid||coverage_data_complete;
            bank_scale_valid[7]<=bank_scale_valid[7]||coverage_data_complete;
          end
        end else begin
          bank_data_valid[coverage_bank]<=bank_data_valid[coverage_bank]||coverage_data_complete;
          bank_scale_valid[coverage_bank]<=bank_scale_valid[coverage_bank]||coverage_scale_complete;
        end
      end
      if(emb_fire_w)begin bank_embedding_lanes[embedding_row*2+:2]<=embedding_lane;
        bank_embedding_lane_valid[embedding_row]<=1;end
      if(inv_fire_w)begin
        if(invalidate_bank==7)begin
          if(invalidate_component!=2)begin rope_invalid_r<=1;
            bank_b7_rope_valid<=0;bank_data_valid[7]<=0;end
          if(invalidate_component!=1)begin static_invalid_r<=1;
            bank_b7_static_valid<=0;bank_scale_valid[7]<=0;end
        end else begin
          invalid_r[invalidate_bank]<=1;bank_data_valid[invalidate_bank]<=0;
          bank_scale_valid[invalidate_bank]<=0;
          if(invalidate_bank==3)bank_embedding_lane_valid<=0;
        end
      end
    end
  end
endmodule
