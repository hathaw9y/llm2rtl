`timescale 1ns/1ps
module dma_bridge_tb;
logic clk;
logic resetn;
logic enable_new_commands;
logic [1:0] cmd_valid;
logic [7:0] cmd_opcode;
logic [223:0] cmd_payload;
logic [23:0] cmd_bank_ids;
logic [63:0] cmd_transaction_id;
logic [191:0] cmd_generations;
logic [1:0] cmd_desc_present;
logic [9:0] cmd_profile;
logic [21:0] cmd_rows;
logic [31:0] cmd_cols;
logic [19:0] cmd_position;
logic [9:0] cmd_layer;
logic [1:0] cmd_data_valid;
logic [1:0] cmd_scale_valid;
logic [1:0] cmd_desc_busy;
logic [9:0] cmd_desc_owner;
logic [63:0] cmd_embedding_lane_valid;
logic [10:0] bank_b7_rope_rows;
logic [31:0] bank_b7_rope_generation;
logic [31:0] bank_b7_static_generation;
logic bank_b7_rope_valid;
logic bank_b7_static_valid;
logic [15:0] bank_ready;
logic [15:0] bank_quiescent;
logic [15:0] wr_pending;
logic [15:0] coverage_pending;
logic mm2s_wr_ready;
logic mm2s_wr_commit;
logic s2mm_rd_ready;
logic s2mm_rd_resp_valid;
logic [127:0] s2mm_rd_data;
logic embedding_ready;
logic [7:0] embedding_error_code;
logic invalidate_ready;
logic [7:0] invalidate_error_code;
logic [1:0] resp_ready;
logic m_axis_mm2s_cmd_tready;
logic [127:0] s_axis_mm2s_tdata;
logic [15:0] s_axis_mm2s_tkeep;
logic s_axis_mm2s_tvalid;
logic s_axis_mm2s_tlast;
logic [7:0] s_axis_mm2s_sts_tdata;
logic s_axis_mm2s_sts_tkeep;
logic s_axis_mm2s_sts_tvalid;
logic s_axis_mm2s_sts_tlast;
logic m_axis_s2mm_cmd_tready;
logic m_axis_s2mm_tready;
logic [7:0] s_axis_s2mm_sts_tdata;
logic s_axis_s2mm_sts_tkeep;
logic s_axis_s2mm_sts_tvalid;
logic s_axis_s2mm_sts_tlast;
logic [1:0] cmd_ready;
logic [1:0] resp_valid;
logic [63:0] resp_transaction_id;
logic [5:0] resp_used_bank_mask;
logic [3:0] resp_used_bank_count;
logic [23:0] resp_bank_ids;
logic [191:0] resp_generations;
logic [15:0] resp_error_code;
logic mm2s_wr_valid;
logic [3:0] mm2s_wr_bank;
logic [18:0] mm2s_wr_word_address;
logic [127:0] mm2s_wr_data;
logic [15:0] mm2s_wr_strb;
logic [31:0] mm2s_wr_transaction_id;
logic [31:0] mm2s_wr_generation;
logic [4:0] mm2s_wr_role;
logic s2mm_rd_valid;
logic [3:0] s2mm_rd_bank;
logic [18:0] s2mm_rd_word_address;
logic embedding_valid;
logic [31:0] embedding_transaction_id;
logic [4:0] embedding_role;
logic [31:0] embedding_generation;
logic [4:0] embedding_row;
logic [1:0] embedding_lane;
logic invalidate_valid;
logic [31:0] invalidate_transaction_id;
logic [4:0] invalidate_role;
logic [3:0] invalidate_bank;
logic [31:0] invalidate_generation;
logic [1:0] invalidate_component;
logic [1:0] faulted;
logic [15:0] fault_reason;
logic [7:0] fault_bank;
logic [63:0] fault_transaction_id;
logic [15:0] fault_raw_status;
logic [7:0] fault_received_tag;
logic [7:0] fault_internal_tag;
logic [1:0] busy;
logic [71:0] m_axis_mm2s_cmd_tdata;
logic m_axis_mm2s_cmd_tvalid;
logic s_axis_mm2s_tready;
logic s_axis_mm2s_sts_tready;
logic [71:0] m_axis_s2mm_cmd_tdata;
logic m_axis_s2mm_cmd_tvalid;
logic [127:0] m_axis_s2mm_tdata;
logic [15:0] m_axis_s2mm_tkeep;
logic m_axis_s2mm_tvalid;
logic m_axis_s2mm_tlast;
logic s_axis_s2mm_sts_tready;
smollm2_dma_transaction_bridge dut(.clk(clk),.resetn(resetn),.enable_new_commands(enable_new_commands),.cmd_valid(cmd_valid),.cmd_opcode(cmd_opcode),.cmd_payload(cmd_payload),.cmd_bank_ids(cmd_bank_ids),.cmd_transaction_id(cmd_transaction_id),.cmd_generations(cmd_generations),.cmd_desc_present(cmd_desc_present),.cmd_profile(cmd_profile),.cmd_rows(cmd_rows),.cmd_cols(cmd_cols),.cmd_position(cmd_position),.cmd_layer(cmd_layer),.cmd_data_valid(cmd_data_valid),.cmd_scale_valid(cmd_scale_valid),.cmd_desc_busy(cmd_desc_busy),.cmd_desc_owner(cmd_desc_owner),.cmd_embedding_lane_valid(cmd_embedding_lane_valid),.bank_b7_rope_rows(bank_b7_rope_rows),.bank_b7_rope_generation(bank_b7_rope_generation),.bank_b7_static_generation(bank_b7_static_generation),.bank_b7_rope_valid(bank_b7_rope_valid),.bank_b7_static_valid(bank_b7_static_valid),.bank_ready(bank_ready),.bank_quiescent(bank_quiescent),.wr_pending(wr_pending),.coverage_pending(coverage_pending),.mm2s_wr_ready(mm2s_wr_ready),.mm2s_wr_commit(mm2s_wr_commit),.s2mm_rd_ready(s2mm_rd_ready),.s2mm_rd_resp_valid(s2mm_rd_resp_valid),.s2mm_rd_data(s2mm_rd_data),.embedding_ready(embedding_ready),.embedding_error_code(embedding_error_code),.invalidate_ready(invalidate_ready),.invalidate_error_code(invalidate_error_code),.resp_ready(resp_ready),.m_axis_mm2s_cmd_tready(m_axis_mm2s_cmd_tready),.s_axis_mm2s_tdata(s_axis_mm2s_tdata),.s_axis_mm2s_tkeep(s_axis_mm2s_tkeep),.s_axis_mm2s_tvalid(s_axis_mm2s_tvalid),.s_axis_mm2s_tlast(s_axis_mm2s_tlast),.s_axis_mm2s_sts_tdata(s_axis_mm2s_sts_tdata),.s_axis_mm2s_sts_tkeep(s_axis_mm2s_sts_tkeep),.s_axis_mm2s_sts_tvalid(s_axis_mm2s_sts_tvalid),.s_axis_mm2s_sts_tlast(s_axis_mm2s_sts_tlast),.m_axis_s2mm_cmd_tready(m_axis_s2mm_cmd_tready),.m_axis_s2mm_tready(m_axis_s2mm_tready),.s_axis_s2mm_sts_tdata(s_axis_s2mm_sts_tdata),.s_axis_s2mm_sts_tkeep(s_axis_s2mm_sts_tkeep),.s_axis_s2mm_sts_tvalid(s_axis_s2mm_sts_tvalid),.s_axis_s2mm_sts_tlast(s_axis_s2mm_sts_tlast),.cmd_ready(cmd_ready),.resp_valid(resp_valid),.resp_transaction_id(resp_transaction_id),.resp_used_bank_mask(resp_used_bank_mask),.resp_used_bank_count(resp_used_bank_count),.resp_bank_ids(resp_bank_ids),.resp_generations(resp_generations),.resp_error_code(resp_error_code),.mm2s_wr_valid(mm2s_wr_valid),.mm2s_wr_bank(mm2s_wr_bank),.mm2s_wr_word_address(mm2s_wr_word_address),.mm2s_wr_data(mm2s_wr_data),.mm2s_wr_strb(mm2s_wr_strb),.mm2s_wr_transaction_id(mm2s_wr_transaction_id),.mm2s_wr_generation(mm2s_wr_generation),.mm2s_wr_role(mm2s_wr_role),.s2mm_rd_valid(s2mm_rd_valid),.s2mm_rd_bank(s2mm_rd_bank),.s2mm_rd_word_address(s2mm_rd_word_address),.embedding_valid(embedding_valid),.embedding_transaction_id(embedding_transaction_id),.embedding_role(embedding_role),.embedding_generation(embedding_generation),.embedding_row(embedding_row),.embedding_lane(embedding_lane),.invalidate_valid(invalidate_valid),.invalidate_transaction_id(invalidate_transaction_id),.invalidate_role(invalidate_role),.invalidate_bank(invalidate_bank),.invalidate_generation(invalidate_generation),.invalidate_component(invalidate_component),.faulted(faulted),.fault_reason(fault_reason),.fault_bank(fault_bank),.fault_transaction_id(fault_transaction_id),.fault_raw_status(fault_raw_status),.fault_received_tag(fault_received_tag),.fault_internal_tag(fault_internal_tag),.busy(busy),.m_axis_mm2s_cmd_tdata(m_axis_mm2s_cmd_tdata),.m_axis_mm2s_cmd_tvalid(m_axis_mm2s_cmd_tvalid),.s_axis_mm2s_tready(s_axis_mm2s_tready),.s_axis_mm2s_sts_tready(s_axis_mm2s_sts_tready),.m_axis_s2mm_cmd_tdata(m_axis_s2mm_cmd_tdata),.m_axis_s2mm_cmd_tvalid(m_axis_s2mm_cmd_tvalid),.m_axis_s2mm_tdata(m_axis_s2mm_tdata),.m_axis_s2mm_tkeep(m_axis_s2mm_tkeep),.m_axis_s2mm_tvalid(m_axis_s2mm_tvalid),.m_axis_s2mm_tlast(m_axis_s2mm_tlast),.s_axis_s2mm_sts_tready(s_axis_s2mm_sts_tready));

always #2.5 clk=~clk;
integer cycles=0, writes=0, reads=0, stores=0, commands=0, tests=0, job_invalidations=0;
logic [2:0] rp;
logic [127:0] dp[3];
logic native_response_enable=1;
logic fail_commit=0;
logic [127:0] last_write;
logic [18:0] last_write_address;
logic [3:0] last_write_bank;
logic [31:0] expected_epoch;
logic [127:0] hold_cmd[2];
logic [1:0] cmd_held;
logic [71:0] cmd_prev[2];
logic [127:0] store_prev;
logic [16:0] store_ctl_prev;
logic store_held;
logic [63:0] response_prev[2];
logic [1:0] response_held;
function automatic [127:0] pattern(input logic [3:0] bank,input logic [18:0] address);
 pattern={32'h67452301 ^ {28'd0,bank},32'hdeadbeef ^ {13'd0,address},32'h13579bdf,32'(address)};
endfunction
assign mm2s_wr_commit=mm2s_wr_valid&&mm2s_wr_ready&&!fail_commit;
assign s2mm_rd_resp_valid=rp[2]&&native_response_enable;
assign s2mm_rd_data=dp[2];
always @(posedge clk) begin
 if(!resetn) begin rp<=0; dp[0]<=0;dp[1]<=0;dp[2]<=0; cmd_held<=0;store_held<=0;response_held<=0; end
 else begin
  cycles<=cycles+1;
  if(cmd_valid[0]&&cmd_ready[0])job_invalidations<=0;
  if(invalidate_valid&&invalidate_ready)job_invalidations<=job_invalidations+1;
  rp<={rp[1:0],s2mm_rd_valid&&s2mm_rd_ready};
  dp[0]<=pattern(s2mm_rd_bank,s2mm_rd_word_address);dp[1]<=dp[0];dp[2]<=dp[1];
  if(mm2s_wr_valid&&mm2s_wr_commit) begin
   writes<=writes+1; last_write<=mm2s_wr_data; last_write_address<=mm2s_wr_word_address; last_write_bank<=mm2s_wr_bank;
   if(mm2s_wr_strb!==16'hffff || mm2s_wr_role!==1 || mm2s_wr_generation!==expected_epoch) $fatal(1,"native MM tuple/strobes");
  end
  if(s2mm_rd_valid&&s2mm_rd_ready) reads<=reads+1;
  if(m_axis_s2mm_tvalid&&m_axis_s2mm_tready) stores<=stores+1;
  for(integer d=0;d<2;d=d+1) begin
   if(cmd_held[d] && (!((d==0)?m_axis_mm2s_cmd_tvalid:m_axis_s2mm_cmd_tvalid) ||
      cmd_prev[d]!==((d==0)?m_axis_mm2s_cmd_tdata:m_axis_s2mm_cmd_tdata))) $fatal(1,"vendor command unstable");
   cmd_held[d]<=((d==0)?(m_axis_mm2s_cmd_tvalid&&!m_axis_mm2s_cmd_tready):(m_axis_s2mm_cmd_tvalid&&!m_axis_s2mm_cmd_tready));
   cmd_prev[d]<=(d==0)?m_axis_mm2s_cmd_tdata:m_axis_s2mm_cmd_tdata;
   if(response_held[d] && (!resp_valid[d] || response_prev[d]!=={resp_transaction_id[d*32+:32],resp_generations[d*96+:32]})) $fatal(1,"response hold");
   response_held[d]<=resp_valid[d]&&!resp_ready[d];
   response_prev[d]<={resp_transaction_id[d*32+:32],resp_generations[d*96+:32]};
  end
  if(store_held && (!m_axis_s2mm_tvalid || m_axis_s2mm_tdata!==store_prev || {m_axis_s2mm_tkeep,m_axis_s2mm_tlast}!==store_ctl_prev)) $fatal(1,"store stream hold");
  store_held<=m_axis_s2mm_tvalid&&!m_axis_s2mm_tready;store_prev<=m_axis_s2mm_tdata;store_ctl_prev<={m_axis_s2mm_tkeep,m_axis_s2mm_tlast};
 end
 if(cycles>200000) $fatal(1,"timeout");
end

task automatic defaults;
 begin
 clk=0;resetn=0;enable_new_commands=1;cmd_valid=0;cmd_opcode=0;cmd_payload=0;cmd_bank_ids=0;cmd_transaction_id=0;cmd_generations=0;
 cmd_desc_present=3;cmd_profile=0;cmd_rows=0;cmd_cols=0;cmd_position=0;cmd_layer=0;cmd_data_valid=3;cmd_scale_valid=3;
 cmd_desc_busy=0;cmd_desc_owner=0;cmd_embedding_lane_valid='1;
 bank_b7_rope_rows=32;bank_b7_rope_generation=7;bank_b7_static_generation=11;bank_b7_rope_valid=1;bank_b7_static_valid=1;
 bank_ready='1;bank_quiescent='1;wr_pending=0;coverage_pending=0;mm2s_wr_ready=1;s2mm_rd_ready=1;
 embedding_ready=1;embedding_error_code=0;invalidate_ready=1;invalidate_error_code=0;resp_ready=0;
 m_axis_mm2s_cmd_tready=0;s_axis_mm2s_tdata=0;s_axis_mm2s_tkeep='1;s_axis_mm2s_tvalid=0;s_axis_mm2s_tlast=0;
 s_axis_mm2s_sts_tdata=0;s_axis_mm2s_sts_tkeep=1;s_axis_mm2s_sts_tvalid=0;s_axis_mm2s_sts_tlast=1;
 m_axis_s2mm_cmd_tready=0;m_axis_s2mm_tready=0;s_axis_s2mm_sts_tdata=0;s_axis_s2mm_sts_tkeep=1;s_axis_s2mm_sts_tvalid=0;s_axis_s2mm_sts_tlast=1;
 native_response_enable=1; fail_commit=0;expected_epoch=3;
 end
endtask

task automatic reset_all;
 begin @(negedge clk);resetn=0;cmd_valid=0;s_axis_mm2s_tvalid=0;s_axis_mm2s_sts_tvalid=0;s_axis_s2mm_sts_tvalid=0;
 repeat(4)@(negedge clk);resetn=1; repeat(3)@(negedge clk); end
endtask

task automatic setup(input integer d,input integer bank,input integer profile,input integer rows,input integer cols,input integer offset,input integer bytes);
 begin
 cmd_opcode[d*4+:4]=4'(d+1); cmd_payload[d*112+:112]={32'(offset),23'(bytes),32'h20000000,25'd0};
 cmd_bank_ids[d*12+:12]=12'(bank);cmd_transaction_id[d*32+:32]=32'(100+tests*2+d);
 cmd_generations[d*96+:96]=(bank==7)?96'((bank_b7_rope_generation>bank_b7_static_generation)?bank_b7_rope_generation:bank_b7_static_generation):96'd3;cmd_profile[d*5+:5]=5'(profile);cmd_rows[d*11+:11]=11'(rows);cmd_cols[d*16+:16]=16'(cols);
 cmd_position[d*10+:10]=0;cmd_layer[d*5+:5]=0;cmd_desc_present[d]=1;cmd_data_valid[d]=1;cmd_scale_valid[d]=1;
 cmd_desc_busy[d]=0;cmd_desc_owner[d*5+:5]=0;cmd_embedding_lane_valid[d*32+:32]='1;
 expected_epoch=(bank==7)?((offset>=4096)?bank_b7_static_generation:bank_b7_rope_generation):3;
 end
endtask

task automatic accept_job(input integer d);
 integer n;
 begin
 @(negedge clk);cmd_valid[d]=1;n=0;
 do begin @(posedge clk);n=n+1;if(n>200)$fatal(1,"cmd accept timeout %0d",d);end while(!cmd_ready[d]);
 @(negedge clk);cmd_valid[d]=0;
 // The descriptor is free before atomic acquisition and becomes owned afterwards.
 cmd_desc_busy[d]=1;cmd_desc_owner[d*5+:5]=5'(d+1);
 end
endtask

task automatic vendor_accept(input integer d,input integer bank,input integer bytes);
 integer n;
 begin
 n=0;
 while(!((d==0)?m_axis_mm2s_cmd_tvalid:m_axis_s2mm_cmd_tvalid))begin @(negedge clk);n++;if(n>200)$fatal(1,"vendor offer timeout d%0d state%0d err%0h",d,dut.state[d],dut.check_error[d]);end
 repeat(3)@(negedge clk);
 if(((d==0)?m_axis_mm2s_cmd_tdata[67:64]:m_axis_s2mm_cmd_tdata[67:64])!==4'(bank))$fatal(1,"vendor tag bank");
 if(((d==0)?m_axis_mm2s_cmd_tdata[22:0]:m_axis_s2mm_cmd_tdata[22:0])!==23'(bytes))$fatal(1,"vendor BTT");
 if(((d==0)?m_axis_mm2s_cmd_tdata[63:32]:m_axis_s2mm_cmd_tdata[63:32])!==cmd_payload[d*112+25+:32])$fatal(1,"vendor DDR address");
 if(d==0)m_axis_mm2s_cmd_tready=1;else m_axis_s2mm_cmd_tready=1;
 @(posedge clk);@(negedge clk);if(d==0)m_axis_mm2s_cmd_tready=0;else m_axis_s2mm_cmd_tready=0;
 commands++;
 end
endtask

task automatic mmbeat(input integer bank,input integer address,input integer keep,input integer last);
 integer n;
 begin
 @(negedge clk);s_axis_mm2s_tvalid=1;s_axis_mm2s_tdata=pattern(4'(bank),19'(address));s_axis_mm2s_tkeep=16'(keep);s_axis_mm2s_tlast=1'(last);n=0;
 do begin @(posedge clk);n++;if(n>200)$fatal(1,"MM beat timeout state=%0d fault=%h innerfault=%h request=%b grant=%b start=%b adapterstate=%0d ready=%b",dut.state[0],faulted,dut.inner_fault,dut.wr_req[bank],dut.wr_grant[bank],dut.mm_start[bank],dut.u_mm2s_adapter.state,s_axis_mm2s_tready);end while(!s_axis_mm2s_tready);
 @(negedge clk);s_axis_mm2s_tvalid=0;
 end
endtask

task automatic status(input integer d,input integer raw,input integer keep,input integer last);
 integer n;
 begin
 @(negedge clk);if(d==0)begin s_axis_mm2s_sts_tdata=8'(raw);s_axis_mm2s_sts_tkeep=1'(keep);s_axis_mm2s_sts_tlast=1'(last);s_axis_mm2s_sts_tvalid=1;end
 else begin s_axis_s2mm_sts_tdata=8'(raw);s_axis_s2mm_sts_tkeep=1'(keep);s_axis_s2mm_sts_tlast=1'(last);s_axis_s2mm_sts_tvalid=1;end
 n=0;do begin @(posedge clk);n++;if(n>200)$fatal(1,"status timeout");end while(!((d==0)?s_axis_mm2s_sts_tready:s_axis_s2mm_sts_tready));
 @(negedge clk);if(d==0)s_axis_mm2s_sts_tvalid=0;else s_axis_s2mm_sts_tvalid=0;
 end
endtask

task automatic complete(input integer d,input integer err);
 integer n;
 begin
 n=0;while(!resp_valid[d])begin @(negedge clk);n++;if(n>400)$fatal(1,"response timeout d%0d state%0d fault%h",d,dut.state[d],faulted);end
 if(resp_error_code[d*8+:8]!==8'(err)||resp_transaction_id[d*32+:32]!==cmd_transaction_id[d*32+:32]||
 resp_bank_ids[d*12+:12]!==cmd_bank_ids[d*12+:12]||resp_generations[d*96+:96]!==cmd_generations[d*96+:96]||
 resp_used_bank_mask[d*3+:3]!==1||resp_used_bank_count[d*2+:2]!==1)$fatal(1,"response identity/error expected%h got%h",err,resp_error_code[d*8+:8]);
 repeat(4)@(negedge clk);resp_ready[d]=1;@(posedge clk);@(negedge clk);resp_ready[d]=0;
 repeat(3)@(negedge clk);if(busy[d])$fatal(1,"completion busy");
 tests++;
 end
endtask

task automatic check_fault(input integer d,input integer reason);
 integer n;
 begin
 n=0;while(!faulted[d])begin @(negedge clk);n++;if(n>200)$fatal(1,"fault timeout");end
 if(reason>=0 && fault_reason[d*8+:8]!==8'(reason))$fatal(1,"fault reason expected%h got%h",reason,fault_reason[d*8+:8]);
 repeat(30)@(negedge clk);
 if(reason>=0 && fault_reason[d*8+:8]!==8'(reason))$fatal(1,"primary fault reason overwritten expected%h got%h",reason,fault_reason[d*8+:8]);
 if(!busy[d]||resp_valid[d]||cmd_ready[d]||fault_transaction_id[d*32+:32]!==cmd_transaction_id[d*32+:32])$fatal(1,"fatal retention");
 if(d==0&&invalidate_pending_r_test())$fatal(1,"invalidation pending");
 if(d==0&&job_invalidations!=1)$fatal(1,"fault invalidation duplicated count%0d",job_invalidations);
 tests++;
 end
endtask
function automatic logic invalidate_pending_r_test();invalidate_pending_r_test=dut.invalidate_pending_r;endfunction

task automatic normal_load(input integer bank,input integer profile,input integer rows,input integer cols,input integer offset,input integer bytes);
 integer w0;
 begin
 setup(0,bank,profile,rows,cols,offset,bytes); w0=writes;accept_job(0);vendor_accept(0,bank,bytes);
 coverage_pending[bank]=1;
 status(0,128+bank,1,1); // status may arrive before native/coverage completes.
 for(integer j=0;j<bytes/16;j++)begin repeat(j%3)@(negedge clk);mmbeat(bank,offset/16+j,65535,j==bytes/16-1);end
 repeat(8)@(negedge clk);if(resp_valid[0])$fatal(1,"early coverage completion");coverage_pending[bank]=0;
 complete(0,0);
 if(writes-w0!=bytes/16 || last_write!==pattern(4'(bank),19'((offset+bytes)/16-1)))$fatal(1,"native write count/data");
 end
endtask

task automatic normal_store(input integer bank,input integer profile,input integer rows,input integer cols,input integer offset,input integer bytes);
 integer r0,s0,j,n;
 begin
 setup(1,bank,profile,rows,cols,offset,bytes);r0=reads;s0=stores;accept_job(1);vendor_accept(1,bank,bytes);status(1,128+bank,1,1);
 for(j=0;j<bytes/16;j++)begin
  m_axis_s2mm_tready=0;n=0;
  while(!m_axis_s2mm_tvalid)begin @(negedge clk);n++;if(n>200)$fatal(1,"store data timeout");end
  repeat(j%4)@(negedge clk);
  if(m_axis_s2mm_tdata!==pattern(4'(bank),19'(offset/16+j)) || m_axis_s2mm_tkeep!==16'hffff || m_axis_s2mm_tlast!==(j==bytes/16-1))$fatal(1,"store data/last j%0d got%h exp%h",j,m_axis_s2mm_tdata,pattern(4'(bank),19'(offset/16+j)));
  m_axis_s2mm_tready=1;@(posedge clk);@(negedge clk);m_axis_s2mm_tready=0;
 end
 complete(1,0);if(reads-r0!=bytes/16||stores-s0!=bytes/16)$fatal(1,"native read count");
 end
endtask

initial begin
 defaults();repeat(4)@(negedge clk);resetn=1;
 // Every physical bank, exact normal reads/writes, random deterministic stalls.
 for(integer bank=0;bank<16;bank++)begin
  if(bank==7)begin normal_load(bank,11,32,64,4096,32);normal_store(bank,11,32,64,4096,32);end
  else begin
   integer p,c,r;
   case(bank)
    0:p=1;1:p=2;2:p=3;3,15:p=4;4:p=7;5:p=9;6:p=10;8:p=12;9:p=14;10:p=16;11:p=19;12:p=20;13:p=21;14:p=23;
    default:p=1;
   endcase
   c=(bank==6||bank==8||bank==9)?192:((bank==12)?49152:((bank==10)?33:576));r=(bank==6||bank==12)?1:2;
   normal_load(bank,p,r,c,16,64);normal_store(bank,p,r,c,16,64);
  end
 end
 normal_load(15,4,192,1536,294912,48);normal_store(15,4,192,1536,294912,48);
 normal_load(8,12,1024,192,196608,16);normal_store(9,14,1024,192,196608,48);
 normal_load(13,22,32,1024,294912,80);normal_store(13,22,32,1024,294912,80);
 normal_load(14,23,17,576,18432,80);normal_load(13,21,17,1536,294912,16);
 normal_load(7,11,32,64,128,32);normal_store(7,11,32,64,128,32);
 // Simultaneous independent channels.
 setup(0,3,4,16,576,0,64);setup(1,15,4,16,576,0,64);accept_job(0);accept_job(1);
 vendor_accept(0,3,64);vendor_accept(1,15,64);
 fork
  begin for(integer j=0;j<4;j++)mmbeat(3,j,65535,j==3);status(0,131,1,1);complete(0,0);end
  begin m_axis_s2mm_tready=1;while(stores<0)@(negedge clk);repeat(30)@(negedge clk);status(1,143,1,1);complete(1,0);m_axis_s2mm_tready=0;end
 join
 // Authenticated embedding event held before success; ignored other lanes.
 setup(0,3,6,32,576,294912+31*16,16);cmd_payload[2:0]=3'b111;embedding_ready=0;
 accept_job(0);vendor_accept(0,3,16);mmbeat(3,18463,65535,1);status(0,131,1,1);
 while(!embedding_valid)@(negedge clk);
 if(embedding_row!==31||embedding_lane!==3||embedding_generation!==3||embedding_transaction_id!==cmd_transaction_id[31:0])$fatal(1,"embedding identity");
 repeat(12)@(negedge clk);if(resp_valid[0])$fatal(1,"early embedding completion");embedding_ready=1;complete(0,0);
 // Clean runtime rejections issue no vendor command; LOAD invalidation ACK held.
 for(integer e=0;e<10;e++)begin
  setup(0,3,4,16,576,0,16);invalidate_ready=0;
  case(e)
   0:cmd_payload[80]=1;
   1:cmd_payload[60:57]=1;
   2:begin cmd_payload[56:25]=32'hfffffff0;cmd_payload[79:57]=32;end
   3:cmd_payload[111:80]=9216;
   4:cmd_payload[24:0]=8;
   5:cmd_desc_present[0]=0;
   6:cmd_generations[31:0]=0;
   7:begin cmd_desc_busy[0]=1;cmd_desc_owner[4:0]=2;end
   8:cmd_bank_ids[7:4]=1;
   9:cmd_generations[63:32]=1;
  endcase
  accept_job(0);repeat(10)@(negedge clk);
  if(m_axis_mm2s_cmd_tvalid||mm2s_wr_valid)$fatal(1,"rejected native access");
  invalidate_ready=1;
  // Canonical response echoes only used tuple, including malformed unused input rejection.
  cmd_bank_ids[11:4]=0;cmd_generations[95:32]=0;
  complete(0,(e<4)?3:((e==4)?1:((e<7)?4:((e==8)?2:7))));
 end
 setup(1,3,6,32,576,0,16);cmd_embedding_lane_valid[63]=0;accept_job(1);complete(1,4);
 setup(1,15,4,16,576,0,16);cmd_scale_valid[1]=0;accept_job(1);complete(1,4);
 // Whole component STORE missing data must be invalid-input04, no mover/native/invalidate.
 setup(1,15,4,16,576,0,16);cmd_data_valid[1]=0;
 begin integer c0,r0; c0=commands;r0=reads;accept_job(1);complete(1,4);
 if(commands!=c0||reads!=r0||invalidate_valid)$fatal(1,"missing STORE data sideeffect");end
 // Complete common error-family differential checks before any vendor/native effect.
 for(integer e=0;e<11;e++)begin
  integer expected,c0,r0,w0;
  setup(1,15,4,16,576,0,16);expected=3;c0=commands;r0=reads;w0=writes;
  case(e)
   0:begin cmd_opcode[7:4]=15;expected=1;end
   1:begin cmd_profile[9:5]=1;expected=2;end
   2:cmd_rows[21:11]=0;
   3:cmd_cols[31:16]=192;
   4:cmd_position[19:10]=1;
   5:begin setup(1,8,12,2,192,0,16);cmd_layer[9:5]=30;end
   6:begin setup(1,7,11,32,64,4096,16);cmd_generations[127:96]=12;expected=7;end
   7:begin setup(1,7,11,32,64,128,16);bank_b7_rope_valid=0;expected=4;end
   8:begin setup(1,7,11,32,64,4096,16);bank_b7_static_valid=0;expected=4;end
   9:begin cmd_payload[112+:3]=1;expected=2;end
   10:begin cmd_payload[112+3]=1;expected=1;end
  endcase
  accept_job(1);complete(1,expected);
  if(commands!=c0||reads!=r0||writes!=w0||invalidate_valid)$fatal(1,"preflight family sideeffect e%0d",e);
  bank_b7_rope_valid=1;bank_b7_static_valid=1;
 end
 // Exclusive DDR end at2^32 is legal; only an address beyond it wraps.
 setup(0,3,4,16,576,0,16);cmd_payload[56:25]=32'hfffffff0;accept_job(0);vendor_accept(0,3,16);
 mmbeat(3,0,65535,1);status(0,131,1,1);complete(0,0);
 // Malformed span consumes diagnostic beat but must never write it.
 for(integer e=0;e<3;e++)begin
  integer w0; reset_all();setup(0,3,4,16,576,0,32);w0=writes;accept_job(0);vendor_accept(0,3,32);
  if(e==0)mmbeat(3,0,32767,0);
  else if(e==1)mmbeat(3,0,65535,1);
  else begin mmbeat(3,0,65535,0);mmbeat(3,1,65535,0);end
  check_fault(0,96);
  if(writes-w0!=((e==2)?1:0))$fatal(1,"bad span wrote native");
 end
 // Wrong bank status, status framing/error bits; diagnostics retain raw external bytes.
 for(integer e=0;e<4;e++)begin
  reset_all();setup(0,15,4,16,576,0,16);accept_job(0);vendor_accept(0,15,16);mmbeat(15,0,65535,1);
  status(0,(e==0)?128:((e==3)?79:143),(e==1)?0:1,(e==2)?0:1);check_fault(0,-1);
  if(fault_raw_status[7:0]!==8'((e==0)?128:((e==3)?79:143)))$fatal(1,"raw diagnostics lost");
 end
 reset_all();setup(0,3,4,16,576,0,16);accept_job(0);vendor_accept(0,3,16);fail_commit=1;mmbeat(3,0,65535,1);check_fault(0,97);fail_commit=0;
 // Abort while read responses remain inflight; no fabricated completion/release.
 reset_all();setup(1,15,4,16,576,0,64);accept_job(1);vendor_accept(1,15,64);
 while(!s2mm_rd_valid)@(negedge clk);status(1,128,1,1);m_axis_s2mm_tready=1;check_fault(1,-1);
 if(dut.read_count_r!==dut.response_count_r)$fatal(1,"fault native responses undrained");
 reset_all();setup(0,3,6,32,576,294912,16);cmd_payload[0]=1;embedding_error_code=7;
 accept_job(0);vendor_accept(0,3,16);mmbeat(3,18432,65535,1);status(0,131,1,1);check_fault(0,98);embedding_error_code=0;
 // Early status while vendor command is held must retain that exact offer.
 reset_all();setup(0,15,4,16,576,0,16);accept_job(0);
 while(!m_axis_mm2s_cmd_tvalid)@(negedge clk);
 enable_new_commands=0;status(0,143,1,1);check_fault(0,-1);
 if(!m_axis_mm2s_cmd_tvalid || m_axis_mm2s_cmd_tdata[67:64]!==15)$fatal(1,"held cmd withdrawn after fatal");
 m_axis_mm2s_cmd_tready=1;@(posedge clk);@(negedge clk);m_axis_mm2s_cmd_tready=0;enable_new_commands=1;
 // B7 malformed static extent targets only static epoch/component, not rope.
 reset_all();setup(0,7,11,32,64,6000,32);invalidate_ready=0;accept_job(0);
 while(!invalidate_valid)@(negedge clk);
 if(invalidate_component!==2 || invalidate_generation!==11 || invalidate_bank!==7)$fatal(1,"B7 wrong fault component");
 repeat(6)@(negedge clk);invalidate_ready=1;complete(0,3);
 // Late duplicate remains unaccepted while a success response is held.
 reset_all();setup(0,3,4,16,576,0,16);accept_job(0);vendor_accept(0,3,16);mmbeat(3,0,65535,1);status(0,131,1,1);
 while(!resp_valid[0])@(negedge clk);
 s_axis_mm2s_sts_tvalid=1;s_axis_mm2s_sts_tdata=128;
 repeat(10)@(negedge clk);if(s_axis_mm2s_sts_tready||!resp_valid[0]||faulted[0])$fatal(1,"late duplicate perturbed response");
 s_axis_mm2s_sts_tvalid=0;complete(0,0);
 // Static B7 is independently resident even before any RoPE window is configured.
 reset_all();bank_b7_rope_rows=0;bank_b7_rope_generation=0;bank_b7_rope_valid=0;
 normal_load(7,11,30,64,4096,16);normal_store(7,11,30,64,4096,16);
 // Malformed static tail still invalidates static epoch11 while rope is absent.
 setup(0,7,11,30,64,6000,32);invalidate_ready=0;accept_job(0);
 while(!invalidate_valid)@(negedge clk);
 if(invalidate_component!==2 || invalidate_generation!==11)$fatal(1,"static-only malformed target");
 invalidate_ready=1;complete(0,3);
 // Missing selected RoPE component has no epoch to invalidate.
 setup(0,7,11,30,64,0,16);accept_job(0);complete(0,4);
 if(invalidate_valid)$fatal(1,"absent component invalidated");
 bank_b7_rope_rows=2;bank_b7_rope_generation=7;bank_b7_rope_valid=1;
 bank_b7_static_generation=0;bank_b7_static_valid=0;
 normal_load(7,11,2,64,0,32);normal_store(7,11,2,64,0,32);
 setup(1,7,11,2,64,4096,16);accept_job(1);complete(1,4);
 bank_b7_rope_rows=32;bank_b7_static_generation=11;bank_b7_static_valid=1;
 // Rejected invalidate is a first metadata fault; never retry it or synthesize response.
 reset_all();setup(0,3,4,16,576,9216,16);invalidate_error_code=7;accept_job(0);check_fault(0,98);invalidate_error_code=0;
 // Live reset then exact retry.
 reset_all();normal_load(3,4,192,1536,0,128);normal_store(15,4,192,1536,0,128);
 $display("DMA_BRIDGE_PASS tests=%0d commands=%0d writes=%0d reads=%0d stores=%0d cycles=%0d",tests,commands,writes,reads,stores,cycles);$finish;
end
endmodule
