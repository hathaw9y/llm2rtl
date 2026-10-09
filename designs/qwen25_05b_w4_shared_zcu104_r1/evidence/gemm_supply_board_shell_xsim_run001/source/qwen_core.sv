// Command executor integration. DDR transport is supplied by common DataMover
// wrapper; runtime PS is responsible only for command/data publication.
module qwen_core(
 input logic clk,rst_n,start,output logic busy,done,error,output logic [7:0] error_code,output logic [9:0] pc,
 output logic cmd_en,output logic [9:0] cmd_addr,input logic [255:0] cmd_data,
 output logic load_valid,input logic load_ready,output logic [31:0] load_address,output logic [22:0] load_bytes,load_offset,output logic [4:0] load_bank,
 input logic load_rsp_valid,output logic load_rsp_ready,input logic [4:0] load_rsp_bank,input logic load_rsp_error,
 output logic store_valid,input logic store_ready,output logic [31:0] store_address,output logic [22:0] store_bytes,store_offset,output logic [4:0] store_bank,
 input logic store_rsp_valid,output logic store_rsp_ready,input logic [4:0] store_rsp_bank,input logic store_rsp_error,
 output logic [22:0] dma_write_grant,dma_read_grant,
 input logic [4:0] dma_write_bank,input logic dma_write_en,input logic [12:0] dma_write_addr,input logic [127:0] dma_write_data,input logic [15:0] dma_write_mask,
 input logic [4:0] dma_read_bank,input logic dma_read_en,input logic [12:0] dma_read_addr,output logic [127:0] dma_read_data
);
 logic [0:22] acquire,release_bank,bank_busy_ascending;
 logic [0:22][4:0] acquire_role,release_role,bank_owner_ascending;
 logic [22:0] write_pending;
 logic [4:0] dispatcher_rsp_ready,completion_quiet;
 logic [22:0] bank_busy;logic [22:0][4:0] bank_owner;
 logic ownership_error;logic [2:0] ownership_error_code;
 logic [4:0] exec_valid,exec_ready,rsp_valid,rsp_ready,rsp_error,exec_commit,exec_commit_error;
 logic [4:0][9:0] rsp_id;logic [4:0][255:0] exec_commit_command;
 logic [255:0] command;logic [9:0] command_id;
 logic descriptor_legal,descriptor_eligible,descriptor_ready,issue;
 logic [22:0] valid,partial,assembling,attention_layout;
 logic [22:0][1:0] format;logic [22:0][10:0] rows;logic [22:0][12:0] cols,covered_columns;
 logic [22:0][15:0] tensor;logic [22:0][5:0] next_group;logic [22:0][17:0] covered_bytes;
 logic [6:0] raw_commit_valid,raw_commit_error;logic [6:0][255:0] raw_commit_command;
 logic [6:0] commit_valid,commit_error;logic [6:0][255:0] commit_command;
 logic [17:0][4:0] role_bank;
 logic [17:0] role_rd_en,role_wr_en;
 logic [17:0][12:0] role_rd_addr,role_wr_addr;
 logic [17:0][127:0] role_rd_data,role_wr_data;
 logic [17:0][15:0] role_wr_mask;
 logic common_load_valid,common_load_ready,common_store_valid,common_store_ready;
 logic [31:0] common_load_offset,common_store_offset;
 logic common_load_rsp_valid,common_store_rsp_valid,common_load_rsp_error,common_store_rsp_error;
 logic common_load_rsp_ready,common_store_rsp_ready;
 logic [4:0] common_load_rsp_bank,common_store_rsp_bank;
 logic bad_load_r,bad_store_r;logic [4:0] bad_load_bank_r,bad_store_bank_r;
 logic [22:0] pending_load,pending_store;
 logic [255:0] saved_load[0:22],saved_store[0:22];
 logic dispatcher_busy,dispatcher_done,dispatcher_error;logic [7:0] dispatcher_error_code;
 logic [7:0] executor_error_code[0:4];
 wire [4:0] ca=command[247+:5],cb=command[242+:5],cc=command[237+:5],cs=command[133+:5];
 wire [4:0] cm=command[128+:5];wire [10:0] cn=command[117+:11],ck=command[106+:11];
 wire [3:0] mode=command[146+:4];wire [7:0] flags=command[138+:8];
 assign busy=dispatcher_busy;assign done=dispatcher_done && !ownership_error;
 assign error=dispatcher_error || ownership_error;
 assign error_code=ownership_error?{5'b11111,ownership_error_code}:dispatcher_error_code;
 for(genvar b=0;b<23;b=b+1)begin
  assign bank_busy[b]=bank_busy_ascending[b];assign bank_owner[b]=bank_owner_ascending[b];
  assign dma_write_grant[b]=bank_busy[b] && bank_owner[b]==1;
  assign dma_read_grant[b]=bank_busy[b] && bank_owner[b]==2;
 end
 bank_ownership_table #(.BANK_NUM(23),.PORT_ROLE_WIDTH(5)) ownership(.aclk(clk),.aresetn(rst_n),
  .acquire_valid(acquire),.acquire_port(acquire_role),.release_valid(release_bank),.release_port(release_role),
  .bank_busy(bank_busy_ascending),.bank_owner_port(bank_owner_ascending),.ownership_error,.ownership_error_code);
 qwen_dispatcher #(.BANK_NUM(23),.BANK_NUM_WIDTH(5),.TAG_WIDTH(5),.PORT_ROLE_WIDTH(5),.CMD_DATA_WIDTH(256)) dispatcher(
  .aclk(clk),.aresetn(rst_n),.cmd_dispatcher_start(start),.cmd_dispatcher_busy(dispatcher_busy),.cmd_dispatcher_done(dispatcher_done),
  .cmd_dispatcher_error(dispatcher_error),.cmd_dispatcher_error_code(dispatcher_error_code),.current_pc(pc),.cmd_enb(cmd_en),.cmd_addrb(cmd_addr),.cmd_doutb(cmd_data),
  .m_ctrl_mm2s_cmd_valid(common_load_valid),.m_ctrl_mm2s_cmd_ready(common_load_ready),.m_ctrl_mm2s_cmd_addr(load_address),.m_ctrl_mm2s_cmd_btt(load_bytes),
  .m_ctrl_mm2s_cmd_offset(common_load_offset),.m_ctrl_mm2s_cmd_bank(load_bank),.m_ctrl_mm2s_cmd_tag(),
  .s_ctrl_mm2s_sts_valid(common_load_rsp_valid),.m_ctrl_mm2s_sts_ready(common_load_rsp_ready),.s_ctrl_mm2s_sts_tag(common_load_rsp_bank),.s_ctrl_mm2s_sts_error(common_load_rsp_error),
  .m_ctrl_s2mm_cmd_valid(common_store_valid),.m_ctrl_s2mm_cmd_ready(common_store_ready),.m_ctrl_s2mm_cmd_addr(store_address),.m_ctrl_s2mm_cmd_btt(store_bytes),
  .m_ctrl_s2mm_cmd_offset(common_store_offset),.m_ctrl_s2mm_cmd_bank(store_bank),.m_ctrl_s2mm_cmd_tag(),
  .s_ctrl_s2mm_sts_valid(common_store_rsp_valid),.m_ctrl_s2mm_sts_ready(common_store_rsp_ready),.s_ctrl_s2mm_sts_tag(common_store_rsp_bank),.s_ctrl_s2mm_sts_error(common_store_rsp_error),
  .bank_acquire_valid(acquire),.bank_acquire_port(acquire_role),.bank_release_valid(release_bank),.bank_release_port(release_role),.bank_busy(bank_busy_ascending),.bank_owner_port(bank_owner_ascending),
  .exec_cmd_valid(exec_valid),.exec_cmd_ready(exec_ready),.exec_command(command),.exec_cmd_id(command_id),
  .exec_rsp_valid(rsp_valid & completion_quiet),.exec_rsp_ready(dispatcher_rsp_ready),.exec_rsp_id(rsp_id),.exec_rsp_error(rsp_error),
  .descriptor_command_legal(descriptor_legal),.descriptor_bank_eligible(descriptor_eligible),.exec_commit_valid(exec_commit),.exec_commit_error,.exec_commit_command);
 // Illegal DMA metadata produces a matched error without forwarding a request.
 // Offsets are narrowed only after descriptor bounds and reserved-field checks.
 wire dma_legal=descriptor_legal && command[18:0]==0 && common_load_offset[31:23]==0 && common_store_offset[31:23]==0;
 assign load_valid=common_load_valid && descriptor_ready && dma_legal;assign store_valid=common_store_valid && descriptor_ready && dma_legal;
 assign common_load_ready=descriptor_ready && (dma_legal?(load_ready && descriptor_eligible):!bad_load_r);
 assign common_store_ready=descriptor_ready && (dma_legal?(store_ready && descriptor_eligible):!bad_store_r);
 assign load_offset=common_load_offset[22:0];assign store_offset=common_store_offset[22:0];
 wire load_write_quiet=load_rsp_bank<23?!write_pending[load_rsp_bank]:!(|write_pending);
 assign load_rsp_ready=common_load_rsp_ready && !bad_load_r && load_write_quiet;
 assign store_rsp_ready=common_store_rsp_ready && !bad_store_r;
 assign common_load_rsp_valid=bad_load_r || (load_rsp_valid && load_write_quiet);assign common_load_rsp_bank=bad_load_r?bad_load_bank_r:load_rsp_bank;
 assign common_load_rsp_error=bad_load_r || load_rsp_error;
 assign common_store_rsp_valid=bad_store_r || store_rsp_valid;assign common_store_rsp_bank=bad_store_r?bad_store_bank_r:store_rsp_bank;
 assign common_store_rsp_error=bad_store_r || store_rsp_error;
 assign issue=(| (exec_valid & exec_ready)) || (common_load_valid && common_load_ready) || (common_store_valid && common_store_ready);
 always @*begin
  raw_commit_valid={exec_commit,2'b00};raw_commit_error={exec_commit_error,2'b00};raw_commit_command='0;
  for(integer e=0;e<5;e=e+1)raw_commit_command[e+2]=exec_commit_command[e];
  if(common_load_rsp_valid && common_load_rsp_ready && common_load_rsp_bank<23 && pending_load[common_load_rsp_bank])begin
   raw_commit_valid[0]=1;raw_commit_error[0]=common_load_rsp_error;raw_commit_command[0]=saved_load[common_load_rsp_bank];
  end
  if(common_store_rsp_valid && common_store_rsp_ready && common_store_rsp_bank<23 && pending_store[common_store_rsp_bank])begin
   raw_commit_valid[1]=1;raw_commit_error[1]=common_store_rsp_error;raw_commit_command[1]=saved_store[common_store_rsp_bank];
  end
 end
 // Semantic completion updates follow a registered packet. Validation
 // flushes on this application; changed physical occupancy blocks stale checks
 // during the intervening cycle. END/DONE follows the last update edge.
 always_ff @(posedge clk)begin
  if(!rst_n)begin commit_valid<=0;commit_error<=0;commit_command<=0;end
  else begin commit_valid<=raw_commit_valid;commit_error<=raw_commit_error;commit_command<=raw_commit_command;end
 end
 always_ff @(posedge clk)begin
  if(!rst_n)begin bad_load_r<=0;bad_store_r<=0;bad_load_bank_r<=0;bad_store_bank_r<=0;pending_load<=0;pending_store<=0;end
  else begin
   if(bad_load_r && common_load_rsp_ready)bad_load_r<=0;if(bad_store_r && common_store_rsp_ready)bad_store_r<=0;
   if(raw_commit_valid[0])pending_load[common_load_rsp_bank]<=0;if(raw_commit_valid[1])pending_store[common_store_rsp_bank]<=0;
   if(common_load_valid && common_load_ready)begin
    pending_load[load_bank]<=1;saved_load[load_bank]<=command;
    if(!dma_legal)begin bad_load_r<=1;bad_load_bank_r<=load_bank;end
   end
   if(common_store_valid && common_store_ready)begin
    pending_store[store_bank]<=1;saved_store[store_bank]<=command;
    if(!dma_legal)begin bad_store_r<=1;bad_store_bank_r<=store_bank;end
   end
  end
 end
 qwen_bank_descriptors descriptors(.clk,.rst_n,.bank_busy,.command,.issue_valid(issue),.command_legal(descriptor_legal),.bank_eligible(descriptor_eligible),.validation_ready(descriptor_ready),
  .commit_valid,.commit_error,.commit_command,.valid,.partial,.assembling,.format,.rows,.cols,.tensor,.attention_layout,.next_group,.covered_bytes,.covered_columns);
 qwen_bank_fabric fabric(.clk,.rst_n,.write_pending,.bank_busy,.bank_owner,.role_bank,.role_rd_en,.role_rd_addr,.role_rd_data,.role_wr_en,.role_wr_addr,.role_wr_data,.role_wr_mask);
 // DMA roles have multiple queued owners. Active bank selectors are provided by
 // the common DMA adapters rather than inferred from the ownership bitmap.
 assign role_bank[0]=0;assign role_rd_en[0]=0;assign role_rd_addr[0]=0;assign role_wr_en[0]=0;assign role_wr_addr[0]=0;assign role_wr_data[0]=0;assign role_wr_mask[0]=0;
 assign role_bank[1]=dma_write_bank;assign role_rd_en[1]=0;assign role_rd_addr[1]=0;
 assign role_wr_en[1]=dma_write_en;assign role_wr_addr[1]=dma_write_addr;assign role_wr_data[1]=dma_write_data;assign role_wr_mask[1]=dma_write_mask;
 assign role_bank[2]=dma_read_bank;assign role_rd_en[2]=dma_read_en;assign role_rd_addr[2]=dma_read_addr;assign dma_read_data=role_rd_data[2];
 assign role_wr_en[2]=0;assign role_wr_addr[2]=0;assign role_wr_data[2]=0;assign role_wr_mask[2]=0;
 // Native selectors must remain the accepted bank IDs while an executor runs.
 logic [4:0] gx,gw,gs,gd,rx,rg,rd,ox,ot,od,sx,sd,vx,vy,vd;
 assign completion_quiet={!write_pending[vd],!write_pending[sd],!write_pending[od],!write_pending[rd],!write_pending[gd]};
 assign rsp_ready=dispatcher_rsp_ready & completion_quiet;
 always_ff @(posedge clk)begin
  if(!rst_n)begin gx<=0;gw<=0;gs<=0;gd<=0;rx<=0;rg<=0;rd<=0;ox<=0;ot<=0;od<=0;sx<=0;sd<=0;vx<=0;vy<=0;vd<=0;end
  else begin
   if(exec_valid[0] && exec_ready[0])begin gx<=ca;gw<=cb;gs<=cs;gd<=cc;end
   if(exec_valid[1] && exec_ready[1])begin rx<=ca;rg<=cb;rd<=cc;end
   if(exec_valid[2] && exec_ready[2])begin ox<=ca;ot<=cb;od<=cc;end
   if(exec_valid[3] && exec_ready[3])begin sx<=ca;sd<=cc;end
   if(exec_valid[4] && exec_ready[4])begin vx<=ca;vy<=cb;vd<=cc;end
  end
 end
 assign role_bank[3]=gx;assign role_bank[4]=gw;assign role_bank[5]=gd;assign role_bank[6]=gs;
 assign role_bank[7]=rx;assign role_bank[8]=rg;assign role_bank[9]=rd;
 assign role_bank[10]=ox;assign role_bank[11]=ot;assign role_bank[12]=od;
 assign role_bank[13]=sx;assign role_bank[14]=sd;assign role_bank[15]=vx;assign role_bank[16]=vy;assign role_bank[17]=vd;
 for(genvar r=3;r<18;r=r+1)begin
  if(r!=5 && r!=9 && r!=12 && r!=14 && r!=17)begin
   assign role_wr_en[r]=0;assign role_wr_addr[r]=0;assign role_wr_data[r]=0;assign role_wr_mask[r]=0;
  end
  if(r==9 || r==12 || r==14 || r==17)begin assign role_rd_en[r]=0;assign role_rd_addr[r]=0;end
 end
 qwen_gemm_executor gemm(.clk,.rst_n,.cmd_valid(exec_valid[0]),.cmd_ready(exec_ready[0]),.cmd_id(command_id),
  .cmd_a(ca),.cmd_b(cb),.cmd_scale(cs),.cmd_dst(cc),.cmd_rows(cm),.cmd_n(cn),.cmd_k(ck),.cmd_mode(mode[1:0]),.cmd_init(flags[0]),
  .rsp_valid(rsp_valid[0]),.rsp_ready(rsp_ready[0]),.rsp_cmd_id(rsp_id[0]),.rsp_error(rsp_error[0]),.rsp_error_code(executor_error_code[0]),
  .act_rd_en(role_rd_en[3]),.act_rd_addr(role_rd_addr[3]),.act_rd_data(role_rd_data[3]),
  .wgt_rd_en(role_rd_en[4]),.wgt_rd_addr(role_rd_addr[4]),.wgt_rd_data(role_rd_data[4]),
  .scale_rd_en(role_rd_en[6]),.scale_rd_addr(role_rd_addr[6]),.scale_rd_data(role_rd_data[6]),
  .dst_rd_en(role_rd_en[5]),.dst_rd_addr(role_rd_addr[5]),.dst_rd_data(role_rd_data[5]),
  .dst_wr_en(role_wr_en[5]),.dst_wr_addr(role_wr_addr[5]),.dst_wr_data(role_wr_data[5]),.dst_wr_mask(role_wr_mask[5]));
 qwen_rmsnorm_executor rms(.clk,.rst_n,.cmd_valid(exec_valid[1]),.cmd_ready(exec_ready[1]),.cmd_id(command_id),
  .cmd_src(ca),.cmd_param(cb),.cmd_dst(cc),.cmd_rows(cm),.cmd_cols(cn),
  .rsp_valid(rsp_valid[1]),.rsp_ready(rsp_ready[1]),.rsp_cmd_id(rsp_id[1]),.rsp_error(rsp_error[1]),.rsp_error_code(executor_error_code[1]),
  .src_rd_en(role_rd_en[7]),.src_rd_addr(role_rd_addr[7]),.src_rd_data(role_rd_data[7]),.param_rd_en(role_rd_en[8]),.param_rd_addr(role_rd_addr[8]),.param_rd_data(role_rd_data[8]),
  .dst_wr_en(role_wr_en[9]),.dst_wr_addr(role_wr_addr[9]),.dst_wr_data(role_wr_data[9]),.dst_wr_mask(role_wr_mask[9]));
 qwen_rope_executor rope(.clk,.rst_n,.cmd_valid(exec_valid[2]),.cmd_ready(exec_ready[2]),.cmd_id(command_id),
  .cmd_src(ca),.cmd_param(cb),.cmd_dst(cc),.cmd_rows(cm),.cmd_heads(cn[3:0]),
  .rsp_valid(rsp_valid[2]),.rsp_ready(rsp_ready[2]),.rsp_cmd_id(rsp_id[2]),.rsp_error(rsp_error[2]),.rsp_error_code(executor_error_code[2]),
  .src_rd_en(role_rd_en[10]),.src_rd_addr(role_rd_addr[10]),.src_rd_data(role_rd_data[10]),.param_rd_en(role_rd_en[11]),.param_rd_addr(role_rd_addr[11]),.param_rd_data(role_rd_data[11]),
  .dst_wr_en(role_wr_en[12]),.dst_wr_addr(role_wr_addr[12]),.dst_wr_data(role_wr_data[12]),.dst_wr_mask(role_wr_mask[12]));
 qwen_softmax_executor softmax(.clk,.rst_n,.cmd_valid(exec_valid[3]),.cmd_ready(exec_ready[3]),.cmd_id(command_id),
  .cmd_src(ca),.cmd_dst(cc),.cmd_rows(cm),.cmd_length(cn),.cmd_position(command[71+:11]),
  .rsp_valid(rsp_valid[3]),.rsp_ready(rsp_ready[3]),.rsp_cmd_id(rsp_id[3]),.rsp_error(rsp_error[3]),.rsp_error_code(executor_error_code[3]),
  .src_rd_en(role_rd_en[13]),.src_rd_addr(role_rd_addr[13]),.src_rd_data(role_rd_data[13]),
  .dst_wr_en(role_wr_en[14]),.dst_wr_addr(role_wr_addr[14]),.dst_wr_data(role_wr_data[14]),.dst_wr_mask(role_wr_mask[14]));
 wire [4:0] vector_dst_rows=flags[7]?command[32+:5]:cm;
 wire [12:0] vector_dst_cols=flags[7]?command[19+:13]:13'(cn);
 qwen_vector_executor vector(.clk,.rst_n,.cmd_valid(exec_valid[4]),.cmd_ready(exec_ready[4]),.cmd_id(command_id),
  .cmd_src0(ca),.cmd_src1(cb),.cmd_dst(cc),.cmd_rows(cm),.cmd_dst_rows(vector_dst_rows),.cmd_cols(cn),
  .cmd_src_rows(rows[ca]),.cmd_src_cols(cols[ca]),.cmd_src1_cols(cols[cb]),.cmd_dst_cols(vector_dst_cols),.cmd_row(command[95+:11]),.cmd_col(command[82+:13]),
  .cmd_mode(mode[2:0]),.cmd_insert(flags[7]),.cmd_begin(flags[6]),
  .rsp_valid(rsp_valid[4]),.rsp_ready(rsp_ready[4]),.rsp_cmd_id(rsp_id[4]),.rsp_error(rsp_error[4]),.rsp_error_code(executor_error_code[4]),
  .src0_rd_en(role_rd_en[15]),.src0_rd_addr(role_rd_addr[15]),.src0_rd_data(role_rd_data[15]),.src1_rd_en(role_rd_en[16]),.src1_rd_addr(role_rd_addr[16]),.src1_rd_data(role_rd_data[16]),
  .dst_wr_en(role_wr_en[17]),.dst_wr_addr(role_wr_addr[17]),.dst_wr_data(role_wr_data[17]),.dst_wr_mask(role_wr_mask[17]));
endmodule
