`timescale 1ns/1ps
module audit_dma_bridge_tb;
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
smollm2_dma_transaction_bridge dut(.clk(clk),
.resetn(resetn),
.enable_new_commands(enable_new_commands),
.cmd_valid(cmd_valid),
.cmd_opcode(cmd_opcode),
.cmd_payload(cmd_payload),
.cmd_bank_ids(cmd_bank_ids),
.cmd_transaction_id(cmd_transaction_id),
.cmd_generations(cmd_generations),
.cmd_desc_present(cmd_desc_present),
.cmd_profile(cmd_profile),
.cmd_rows(cmd_rows),
.cmd_cols(cmd_cols),
.cmd_position(cmd_position),
.cmd_layer(cmd_layer),
.cmd_data_valid(cmd_data_valid),
.cmd_scale_valid(cmd_scale_valid),
.cmd_desc_busy(cmd_desc_busy),
.cmd_desc_owner(cmd_desc_owner),
.cmd_embedding_lane_valid(cmd_embedding_lane_valid),
.bank_b7_rope_rows(bank_b7_rope_rows),
.bank_b7_rope_generation(bank_b7_rope_generation),
.bank_b7_static_generation(bank_b7_static_generation),
.bank_b7_rope_valid(bank_b7_rope_valid),
.bank_b7_static_valid(bank_b7_static_valid),
.bank_ready(bank_ready),
.bank_quiescent(bank_quiescent),
.wr_pending(wr_pending),
.coverage_pending(coverage_pending),
.mm2s_wr_ready(mm2s_wr_ready),
.mm2s_wr_commit(mm2s_wr_commit),
.s2mm_rd_ready(s2mm_rd_ready),
.s2mm_rd_resp_valid(s2mm_rd_resp_valid),
.s2mm_rd_data(s2mm_rd_data),
.embedding_ready(embedding_ready),
.embedding_error_code(embedding_error_code),
.invalidate_ready(invalidate_ready),
.invalidate_error_code(invalidate_error_code),
.resp_ready(resp_ready),
.m_axis_mm2s_cmd_tready(m_axis_mm2s_cmd_tready),
.s_axis_mm2s_tdata(s_axis_mm2s_tdata),
.s_axis_mm2s_tkeep(s_axis_mm2s_tkeep),
.s_axis_mm2s_tvalid(s_axis_mm2s_tvalid),
.s_axis_mm2s_tlast(s_axis_mm2s_tlast),
.s_axis_mm2s_sts_tdata(s_axis_mm2s_sts_tdata),
.s_axis_mm2s_sts_tkeep(s_axis_mm2s_sts_tkeep),
.s_axis_mm2s_sts_tvalid(s_axis_mm2s_sts_tvalid),
.s_axis_mm2s_sts_tlast(s_axis_mm2s_sts_tlast),
.m_axis_s2mm_cmd_tready(m_axis_s2mm_cmd_tready),
.m_axis_s2mm_tready(m_axis_s2mm_tready),
.s_axis_s2mm_sts_tdata(s_axis_s2mm_sts_tdata),
.s_axis_s2mm_sts_tkeep(s_axis_s2mm_sts_tkeep),
.s_axis_s2mm_sts_tvalid(s_axis_s2mm_sts_tvalid),
.s_axis_s2mm_sts_tlast(s_axis_s2mm_sts_tlast),
.cmd_ready(cmd_ready),
.resp_valid(resp_valid),
.resp_transaction_id(resp_transaction_id),
.resp_used_bank_mask(resp_used_bank_mask),
.resp_used_bank_count(resp_used_bank_count),
.resp_bank_ids(resp_bank_ids),
.resp_generations(resp_generations),
.resp_error_code(resp_error_code),
.mm2s_wr_valid(mm2s_wr_valid),
.mm2s_wr_bank(mm2s_wr_bank),
.mm2s_wr_word_address(mm2s_wr_word_address),
.mm2s_wr_data(mm2s_wr_data),
.mm2s_wr_strb(mm2s_wr_strb),
.mm2s_wr_transaction_id(mm2s_wr_transaction_id),
.mm2s_wr_generation(mm2s_wr_generation),
.mm2s_wr_role(mm2s_wr_role),
.s2mm_rd_valid(s2mm_rd_valid),
.s2mm_rd_bank(s2mm_rd_bank),
.s2mm_rd_word_address(s2mm_rd_word_address),
.embedding_valid(embedding_valid),
.embedding_transaction_id(embedding_transaction_id),
.embedding_role(embedding_role),
.embedding_generation(embedding_generation),
.embedding_row(embedding_row),
.embedding_lane(embedding_lane),
.invalidate_valid(invalidate_valid),
.invalidate_transaction_id(invalidate_transaction_id),
.invalidate_role(invalidate_role),
.invalidate_bank(invalidate_bank),
.invalidate_generation(invalidate_generation),
.invalidate_component(invalidate_component),
.faulted(faulted),
.fault_reason(fault_reason),
.fault_bank(fault_bank),
.fault_transaction_id(fault_transaction_id),
.fault_raw_status(fault_raw_status),
.fault_received_tag(fault_received_tag),
.fault_internal_tag(fault_internal_tag),
.busy(busy),
.m_axis_mm2s_cmd_tdata(m_axis_mm2s_cmd_tdata),
.m_axis_mm2s_cmd_tvalid(m_axis_mm2s_cmd_tvalid),
.s_axis_mm2s_tready(s_axis_mm2s_tready),
.s_axis_mm2s_sts_tready(s_axis_mm2s_sts_tready),
.m_axis_s2mm_cmd_tdata(m_axis_s2mm_cmd_tdata),
.m_axis_s2mm_cmd_tvalid(m_axis_s2mm_cmd_tvalid),
.m_axis_s2mm_tdata(m_axis_s2mm_tdata),
.m_axis_s2mm_tkeep(m_axis_s2mm_tkeep),
.m_axis_s2mm_tvalid(m_axis_s2mm_tvalid),
.m_axis_s2mm_tlast(m_axis_s2mm_tlast),
.s_axis_s2mm_sts_tready(s_axis_s2mm_sts_tready));
logic[2:0]rdpipe;logic[18:0]rdaddr[0:2];int writes,reads,stores,cycles,invalidations;bit expect_fault;int expected_wr_bank=2,expected_wr_gen=1,expected_wr_txn=101,expected_wr_base=0,expected_rd_bank=2,expected_rd_base=0,expected_store_beats=8;
assign mm2s_wr_commit=mm2s_wr_valid&&mm2s_wr_ready;
assign s2mm_rd_resp_valid=rdpipe[2];
assign s2mm_rd_data={32'h98765432,32'(rdaddr[2]),32'habcdef01,32'(rdaddr[2])};
always #2.5 clk=~clk;
always @(posedge clk)begin
 cycles++;if(cycles>5000)$fatal(1,"watchdog");
 if(!resetn)begin rdpipe<=0;writes=0;reads=0;stores=0;invalidations=0;end
 else begin
  if(invalidate_valid&&invalidate_ready)invalidations++;
  rdpipe<={rdpipe[1:0],s2mm_rd_valid&&s2mm_rd_ready};rdaddr[2]<=rdaddr[1];rdaddr[1]<=rdaddr[0];if(s2mm_rd_valid&&s2mm_rd_ready)rdaddr[0]<=s2mm_rd_word_address;
  if(mm2s_wr_valid)begin
   if(mm2s_wr_bank!=4'(expected_wr_bank)||mm2s_wr_word_address!=19'(expected_wr_base+writes)||mm2s_wr_strb!=16'hffff||mm2s_wr_transaction_id!=32'(expected_wr_txn)||mm2s_wr_generation!=32'(expected_wr_gen)||mm2s_wr_role!=1)$fatal(1,"MM2S native tuple/address mismatch");
   if(mm2s_wr_data!=={4{32'(writes)}})$fatal(1,"MM2S byte payload mismatch");writes++;
  end
  if(s2mm_rd_valid&&s2mm_rd_ready)begin if(s2mm_rd_bank!=4'(expected_rd_bank)||s2mm_rd_word_address!=19'(expected_rd_base+reads))$fatal(1,"S2MM native address mismatch");reads++;end
  if(m_axis_s2mm_tvalid&&m_axis_s2mm_tready)begin
   if(m_axis_s2mm_tdata!=={32'h98765432,32'(expected_rd_base+stores),32'habcdef01,32'(expected_rd_base+stores)}||m_axis_s2mm_tkeep!=16'hffff||m_axis_s2mm_tlast!=(stores==expected_store_beats-1))$fatal(1,"S2MM payload or span");stores++;
  end
 end
end
task automatic ticks(input int n);repeat(n)@(negedge clk);endtask
task automatic boot;
 resetn=0;ticks(4);resetn=1;ticks(3);
endtask
task automatic command(input int d,input int txn,input logic[111:0]payload,input int bankid=2,input int profile=3,input int rows=1,input int cols=576,input int gen=1,input bit validdata=1,input bit validscale=0,input logic[31:0]validlanes=0,input int op=-1,input int pos=0,input int lyr=0,input int own=0);
 cmd_opcode[d*4+:4]=(op<0)?4'(d+1):4'(op);cmd_payload[d*112+:112]=payload;cmd_bank_ids[d*12+:12]=12'(bankid);cmd_transaction_id[d*32+:32]=32'(txn);cmd_generations[d*96+:96]=96'(gen);cmd_desc_present[d]=1;cmd_profile[d*5+:5]=5'(profile);cmd_rows[d*11+:11]=11'(rows);cmd_cols[d*16+:16]=16'(cols);cmd_position[d*10+:10]=10'(pos);cmd_layer[d*5+:5]=5'(lyr);cmd_embedding_lane_valid[d*32+:32]=validlanes;cmd_data_valid[d]=validdata;cmd_scale_valid[d]=validscale;cmd_desc_busy[d]=(own!=0);cmd_desc_owner[d*5+:5]=5'(own);cmd_valid[d]=1;
 do @(posedge clk);while(!cmd_ready[d]);@(negedge clk);cmd_valid[d]=0;
 // Every accepted field must be captured; live inputs change immediately after acceptance.
 cmd_opcode[d*4+:4]='1;cmd_payload[d*112+:112]='1;cmd_bank_ids[d*12+:12]='1;cmd_transaction_id[d*32+:32]='1;cmd_generations[d*96+:96]='1;cmd_desc_present[d]=0;cmd_profile[d*5+:5]='1;cmd_rows[d*11+:11]='1;cmd_cols[d*16+:16]='1;cmd_position[d*10+:10]='1;cmd_layer[d*5+:5]='1;cmd_data_valid[d]=0;cmd_scale_valid[d]=0;cmd_desc_busy[d]=1;cmd_desc_owner[d*5+:5]='1;cmd_embedding_lane_valid[d*32+:32]='1;bank_b7_rope_rows=0;bank_b7_rope_generation=0;bank_b7_static_generation=0;bank_b7_rope_valid=0;bank_b7_static_valid=0;
endtask
task automatic status(input int d,input logic[7:0]s);
 if(d==0)begin s_axis_mm2s_sts_tdata=s;s_axis_mm2s_sts_tvalid=1;do @(posedge clk);while(!s_axis_mm2s_sts_tready);@(negedge clk);s_axis_mm2s_sts_tvalid=0;end
 else begin s_axis_s2mm_sts_tdata=s;s_axis_s2mm_sts_tvalid=1;do @(posedge clk);while(!s_axis_s2mm_sts_tready);@(negedge clk);s_axis_s2mm_sts_tvalid=0;end
endtask
task automatic load_data(input int n=72);
 for(int k=0;k<n;k++)begin s_axis_mm2s_tdata={4{32'(k)}};s_axis_mm2s_tkeep=16'hffff;s_axis_mm2s_tlast=(k==n-1);s_axis_mm2s_tvalid=1;do @(posedge clk);while(!s_axis_mm2s_tready);@(negedge clk);s_axis_mm2s_tvalid=0;end
endtask
task automatic response(input int d,input int txn,input int bankid=2,input int gen=1);
 begin int timeout;timeout=0;while(!resp_valid[d]&&timeout<200)begin ticks(1);timeout++;end;if(!resp_valid[d])$fatal(1,"outer response timeout");end
 for(int k=0;k<7;k++)begin
  if(!resp_valid[d]||resp_transaction_id[d*32+:32]!=32'(txn)||resp_used_bank_mask[d*3+:3]!=1||resp_used_bank_count[d*2+:2]!=1||resp_bank_ids[d*12+:12]!=12'(bankid)||resp_generations[d*96+:96]!=96'(gen)||resp_error_code[d*8+:8]!=0)$fatal(1,"stable exact outer response");ticks(1);
 end
 resp_ready[d]=1;ticks(1);resp_ready[d]=0;ticks(3);if(busy[d]||faulted[d])$fatal(1,"completed transaction not idle");
endtask
task automatic coverage_rejection(input int txn,input int bankid,input int gen,input int code=4);
 begin int t;t=0;while(!resp_valid[1]&&t<40)begin ticks(1);t++;end if(!resp_valid[1])$fatal(1,"coverage reject timeout");end
 for(int k=0;k<7;k++)begin
  if(resp_error_code[15:8]!=8'(code)||resp_transaction_id[63:32]!=32'(txn)||resp_bank_ids[23:12]!=12'(bankid)||resp_generations[191:96]!=96'(gen)||resp_used_bank_mask[5:3]!=1||resp_used_bank_count[3:2]!=1)$fatal(1,"preflight classification txn%0d expected%h got%h",txn,code,resp_error_code[15:8]);
  if(m_axis_s2mm_cmd_tvalid||s2mm_rd_valid||invalidate_valid||reads!=0||invalidations!=0)$fatal(1,"unready STORE touched source/vendor/invalidation");ticks(1);
 end
 resp_ready[1]=1;ticks(1);resp_ready[1]=0;ticks(3);if(busy[1]||faulted[1])$fatal(1,"clean coverage reject notretired");
endtask
initial begin
 clk=0;resetn=0;cycles=0;expect_fault=0;
enable_new_commands='0;
cmd_valid='0;
cmd_opcode='0;
cmd_payload='0;
cmd_bank_ids='0;
cmd_transaction_id='0;
cmd_generations='0;
cmd_desc_present='0;
cmd_profile='0;
cmd_rows='0;
cmd_cols='0;
cmd_position='0;
cmd_layer='0;
cmd_data_valid='0;
cmd_scale_valid='0;
cmd_desc_busy='0;
cmd_desc_owner='0;
cmd_embedding_lane_valid='0;
bank_b7_rope_rows='0;
bank_b7_rope_generation='0;
bank_b7_static_generation='0;
bank_b7_rope_valid='0;
bank_b7_static_valid='0;
bank_ready='0;
bank_quiescent='0;
wr_pending='0;
coverage_pending='0;
mm2s_wr_ready='0;
s2mm_rd_ready='0;
embedding_ready='0;
embedding_error_code='0;
invalidate_ready='0;
invalidate_error_code='0;
resp_ready='0;
m_axis_mm2s_cmd_tready='0;
s_axis_mm2s_tdata='0;
s_axis_mm2s_tkeep='0;
s_axis_mm2s_tvalid='0;
s_axis_mm2s_tlast='0;
s_axis_mm2s_sts_tdata='0;
s_axis_mm2s_sts_tkeep='0;
s_axis_mm2s_sts_tvalid='0;
s_axis_mm2s_sts_tlast='0;
m_axis_s2mm_cmd_tready='0;
m_axis_s2mm_tready='0;
s_axis_s2mm_sts_tdata='0;
s_axis_s2mm_sts_tkeep='0;
s_axis_s2mm_sts_tvalid='0;
s_axis_s2mm_sts_tlast='0;
 enable_new_commands=1;bank_ready=16'hffff;bank_quiescent=16'hffff;mm2s_wr_ready=1;s2mm_rd_ready=1;embedding_ready=1;invalidate_ready=1;m_axis_mm2s_cmd_tready=1;m_axis_s2mm_cmd_tready=1;m_axis_s2mm_tready=1;s_axis_mm2s_sts_tkeep=1;s_axis_mm2s_sts_tlast=1;s_axis_s2mm_sts_tkeep=1;s_axis_s2mm_sts_tlast=1;
 boot();m_axis_mm2s_cmd_tready=0;command(0,101,112'h0000000000090000200000000000);while(!m_axis_mm2s_cmd_tvalid)ticks(1);begin logic[71:0]held;held=m_axis_mm2s_cmd_tdata;for(int k=0;k<10;k++)begin ticks(1);if(!m_axis_mm2s_cmd_tvalid||m_axis_mm2s_cmd_tdata!==held)$fatal(1,"stalled vendor command changed");end if(held[67:64]!=2||held[22:0]!=1152||held[63:32]!=32'h100000)$fatal(1,"vendor command byte span/tag");end m_axis_mm2s_cmd_tready=1;load_data();status(0,8'h82);response(0,101);if(writes!=72)$fatal(1,"load exact bytes");
 m_axis_s2mm_tready=0;command(1,202,112'h0000000000010000400000000000);while(!m_axis_s2mm_tvalid)ticks(1);begin logic[144:0]held;held={m_axis_s2mm_tdata,m_axis_s2mm_tkeep,m_axis_s2mm_tlast};for(int k=0;k<20;k++)begin ticks(1);if(!m_axis_s2mm_tvalid||{m_axis_s2mm_tdata,m_axis_s2mm_tkeep,m_axis_s2mm_tlast}!==held)$fatal(1,"held S2MM beat changed");end end m_axis_s2mm_tready=1;while(stores<8)ticks(1);bank_quiescent[2]=0;status(1,8'h82);ticks(10);if(resp_valid[1]||!busy[1])$fatal(1,"quiescence barrier bypass");bank_quiescent[2]=1;response(1,202);if(reads!=8||stores!=8)$fatal(1,"read accounting");
 // Fresh wrong vendor tag is fatal and retains ownership/busy until reset.
 boot();command(0,101,112'h0000000000090000200000000000);load_data();status(0,8'h83);ticks(40);if(!faulted[0]||!busy[0]||resp_valid[0]||fault_received_tag[3:0]!=3||fault_raw_status[7:0]!=8'h83)$fatal(1,"fatal tag diagnostics or fabricated completion");
 // Malformed static range must invalidate selected static epoch, preserving RoPE.
 boot();invalidate_ready=0;bank_b7_rope_rows=2;bank_b7_rope_generation=7;bank_b7_static_generation=11;bank_b7_rope_valid=1;bank_b7_static_valid=1;
 command(0,303,112'h0000177000004000600000000000,7,11,2,64,11);while(!invalidate_valid)ticks(1);
 for(int k=0;k<7;k++)begin
  if(!invalidate_valid||invalidate_bank!=7||invalidate_component!=2||invalidate_generation!=11||invalidate_transaction_id!=303||invalidate_role!=1)$fatal(1,"B7 rejected static range targets wrong component/epoch got component%0d gen%0d",invalidate_component,invalidate_generation);
  if(m_axis_mm2s_cmd_tvalid||mm2s_wr_valid||resp_valid[0])$fatal(1,"rejected range touched transport or bypassed ACK");ticks(1);
 end
 invalidate_ready=1;while(!resp_valid[0])ticks(1);if(resp_error_code[7:0]!=3||resp_bank_ids[11:0]!=7||resp_generations[95:0]!=11||resp_transaction_id[31:0]!=303||faulted[0]||writes!=0)$fatal(1,"B7 range reject completion");
 resp_ready[0]=1;ticks(1);resp_ready[0]=0;ticks(3);
 // Valid resident static component works with no RoPE/window component at all.
 bank_b7_rope_rows=0;bank_b7_rope_generation=0;bank_b7_rope_valid=0;bank_b7_static_generation=11;bank_b7_static_valid=1;m_axis_mm2s_cmd_tready=0;
 command(0,404,112'h0000100000002000600000000000,7,11,30,64,11);
 begin int t;t=0;while(!m_axis_mm2s_cmd_tvalid&&t<30)begin ticks(1);t++;if(resp_valid[0])$fatal(1,"valid B7 static-only LOAD rejected error%h",resp_error_code[7:0]);end if(!m_axis_mm2s_cmd_tvalid)$fatal(1,"static-only admission timeout");end
 if(m_axis_mm2s_cmd_tdata[67:64]!=7||m_axis_mm2s_cmd_tdata[22:0]!=16||writes!=0||!busy[0])$fatal(1,"static-only command or no-touch before vendor acceptance");
 m_axis_mm2s_cmd_tready=1;expected_wr_bank=7;expected_wr_gen=11;expected_wr_txn=404;expected_wr_base=256;load_data(1);status(0,8'h87);response(0,404,7,11);if(writes!=1)$fatal(1,"static-only LOAD writes");
 // Static-only STORE does not require RoPE; selected component source readiness suffices.
 bank_b7_rope_rows=0;bank_b7_rope_generation=0;bank_b7_rope_valid=0;bank_b7_static_generation=11;bank_b7_static_valid=1;expected_rd_bank=7;expected_rd_base=256;expected_store_beats=1;reads=0;stores=0;
 command(1,505,112'h0000100000002000640000000000,7,11,30,64,11);while(stores<1)ticks(1);status(1,8'h87);response(1,505,7,11);if(reads!=1)$fatal(1,"static-only STORE reads");
 // Unequal B7 epochs: rope native generation1, original aggregate completion11.
 bank_b7_rope_rows=1;bank_b7_rope_generation=1;bank_b7_rope_valid=1;bank_b7_static_generation=11;bank_b7_static_valid=1;expected_wr_bank=7;expected_wr_gen=1;expected_wr_txn=606;expected_wr_base=0;writes=0;
 command(0,606,112'h0000000000010000620000000000,7,11,1,64,11);load_data(8);status(0,8'h87);response(0,606,7,11);if(writes!=8)$fatal(1,"unequal rope epoch transfer");
 // First transport fault survives scheduler-abort drain; target invalidated exactly once.
 boot();m_axis_mm2s_cmd_tready=1;command(0,101,112'h0000000000090000200000000000);s_axis_mm2s_tvalid=1;s_axis_mm2s_tdata=128'h12345678;s_axis_mm2s_tkeep=16'hfffe;s_axis_mm2s_tlast=0;do @(posedge clk);while(!s_axis_mm2s_tready);@(negedge clk);s_axis_mm2s_tvalid=0;ticks(2);
 for(int k=0;k<80;k++)begin
  if(!faulted[0]||!busy[0]||resp_valid[0]||fault_reason[7:0]!=8'h60||fault_bank[3:0]!=2||fault_transaction_id[31:0]!=101||writes!=0)$fatal(1,"first partialKEEP60 fault changed during drain reason%h invalidations%0d",fault_reason[7:0],invalidations);ticks(1);
 end
 if(invalidations!=1)$fatal(1,"LOAD fatal invalidated target %0d times",invalidations);
 // Common04 for missing data/scales/selectors and individually unavailable B7 components.
 boot();command(1,808,112'h0000000000010000400000000000,2,3,1,576,1,0,0,0);coverage_rejection(808,2,1);
 command(1,809,112'h0000000000010000400000000000,3,4,16,576,1,1,0,0);coverage_rejection(809,3,1);
 command(1,810,112'h0000000000010000400000000000,3,6,1,576,1,1,1,0);coverage_rejection(810,3,1);
 bank_b7_rope_rows=1;bank_b7_rope_generation=1;bank_b7_rope_valid=0;bank_b7_static_generation=11;bank_b7_static_valid=1;command(1,811,112'h0000000000002000660000000000,7,11,1,64,11,1,1,0);coverage_rejection(811,7,11);
 bank_b7_rope_rows=0;bank_b7_rope_generation=0;bank_b7_rope_valid=0;bank_b7_static_generation=11;bank_b7_static_valid=0;command(1,812,112'h0000100000002000640000000000,7,11,30,64,11,1,1,0);coverage_rejection(812,7,11);
 // Clean STORE classification: geometry/span03, opcode/reserved01, profile02, identity07.
 begin logic[111:0]p;p=112'h0000000000010000400000000000;p[111:80]=1136;p[79:57]=32;command(1,901,p);coverage_rejection(901,2,1,3);end
 begin logic[111:0]p;p=112'h0000000000010000400000000000;p[111:80]=1;command(1,902,p);coverage_rejection(902,2,1,3);end
 begin logic[111:0]p;p=112'h0000000000010000400000000000;p[56:25]=32'hfffffff0;command(1,903,p);coverage_rejection(903,2,1,3);end
 begin logic[111:0]p;p=112'h0000000000010000400000000000;p[79:57]=0;command(1,904,p);coverage_rejection(904,2,1,3);end
 begin logic[111:0]p;p=112'h0000000000010000400000000000;p[3]=1;command(1,905,p);coverage_rejection(905,2,1,1);end
 command(1,906,112'h0000000000010000400000000000,2,3,1,576,1,1,0,0,1);coverage_rejection(906,2,1,1);
 command(1,907,112'h0000000000010000400000000000,2,31,1,576,1);coverage_rejection(907,2,1,2);
 command(1,908,112'h0000000000010000400000000000,2,3,0,576,1);coverage_rejection(908,2,1,3);
 command(1,909,112'h0000000000010000400000000000,8,12,1,64,1,1,1,0,-1,0,30);coverage_rejection(909,8,1,3);
 command(1,910,112'h0000000000010000400000000000,13,17,1,33,1,1,0,0,-1,33,0);coverage_rejection(910,13,1,3);
 command(1,911,112'h0000000000010000400000000000,2,3,1,576,1,1,0,0,-1,0,0,3);coverage_rejection(911,2,1,7);
 bank_b7_rope_rows=1;bank_b7_rope_generation=1;bank_b7_rope_valid=1;bank_b7_static_generation=10;bank_b7_static_valid=1;command(1,912,112'h0000100000002000640000000000,7,11,30,64,11,1,1);coverage_rejection(912,7,11,7);
 command(1,913,112'h0000000000010000400000000000,2,4,16,576,1,1,1);coverage_rejection(913,2,1,2);
 command(1,914,112'h0000000000010000400000000000,2,3,1,576,0);coverage_rejection(914,2,0,7);
 $display("AUDIT_DMA_BRIDGE_PASS writes=%0d reads=%0d stores=%0d cycles=%0d",writes,reads,stores,cycles);$finish;
end
endmodule
