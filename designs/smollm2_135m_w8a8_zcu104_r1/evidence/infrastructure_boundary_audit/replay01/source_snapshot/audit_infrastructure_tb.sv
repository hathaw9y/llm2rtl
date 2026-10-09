`timescale 1ns/1ps
module audit_infrastructure_tb;
logic clk;
logic resetn;
logic start;
logic [127:0] cmd_doutb;
logic busy;
logic done;
logic error;
logic [7:0] error_code;
logic [3:0] current_pc;
logic cmd_enb;
logic [3:0] cmd_addrb;
logic [15:0] bank_busy;
logic [79:0] bank_owner_port;
logic [15:0] bank_desc_present;
logic [79:0] bank_profiles;
logic [175:0] bank_rows;
logic [255:0] bank_cols;
logic [159:0] bank_positions;
logic [79:0] bank_layers;
logic [511:0] bank_generations;
logic [15:0] bank_data_valid;
logic [15:0] bank_scale_valid;
logic bank_b7_static_valid;
logic bank_b7_rope_valid;
logic [63:0] bank_embedding_lanes;
logic [31:0] bank_embedding_lane_valid;
logic acquire_valid;
logic [31:0] acquire_transaction_id;
logic [2:0] acquire_used_bank_mask;
logic [11:0] acquire_bank_ids;
logic [14:0] acquire_roles;
logic [95:0] acquire_generations;
logic acquire_ready;
logic [7:0] acquire_error_code;
logic release_valid;
logic [31:0] release_transaction_id;
logic [2:0] release_used_bank_mask;
logic [11:0] release_bank_ids;
logic [14:0] release_roles;
logic [95:0] release_generations;
logic release_ready;
logic [7:0] release_error_code;
logic cfg_valid;
logic [31:0] cfg_transaction_id;
logic [3:0] cfg_bank;
logic [4:0] cfg_profile;
logic [10:0] cfg_rows;
logic [15:0] cfg_cols;
logic [9:0] cfg_position;
logic [4:0] cfg_layer;
logic [1:0] cfg_component;
logic [31:0] cfg_generation;
logic cfg_resp_ready;
logic cfg_ready;
logic cfg_resp_valid;
logic [31:0] cfg_resp_transaction_id;
logic [7:0] cfg_resp_error_code;
logic [3:0] engine_cmd_ready;
logic [3:0] engine_cmd_valid;
logic [15:0] engine_cmd_opcode;
logic [447:0] engine_cmd_payload;
logic [47:0] engine_cmd_bank_ids;
logic [127:0] engine_cmd_transaction_id;
logic [383:0] engine_cmd_generations;
logic [11:0] engine_cmd_desc_present;
logic [59:0] engine_cmd_profiles;
logic [131:0] engine_cmd_rows;
logic [191:0] engine_cmd_cols;
logic [119:0] engine_cmd_positions;
logic [59:0] engine_cmd_layers;
logic [383:0] engine_cmd_desc_generations;
logic [11:0] engine_cmd_data_valid;
logic [11:0] engine_cmd_scale_valid;
logic [11:0] engine_cmd_desc_busy;
logic [59:0] engine_cmd_desc_owner;
logic [3:0] engine_cmd_b7_static_valid;
logic [255:0] engine_cmd_embedding_lanes;
logic [127:0] engine_cmd_embedding_lane_valid;
logic [3:0] engine_resp_valid;
logic [127:0] engine_resp_transaction_id;
logic [11:0] engine_resp_used_bank_mask;
logic [7:0] engine_resp_used_bank_count;
logic [47:0] engine_resp_bank_ids;
logic [383:0] engine_resp_generations;
logic [31:0] engine_resp_error_code;
logic [3:0] engine_resp_ready;
logic producer_valid;
logic [31:0] producer_transaction_id;
logic [4:0] producer_role;
logic [3:0] producer_bank;
logic [31:0] producer_accepted_generation;
logic [31:0] producer_generation;
logic [4:0] producer_profile;
logic [10:0] producer_rows;
logic [15:0] producer_cols;
logic [9:0] producer_position;
logic [4:0] producer_layer;
logic producer_ready;
logic [7:0] producer_error_code;
logic invalidate_valid;
logic [31:0] invalidate_transaction_id;
logic [4:0] invalidate_role;
logic [3:0] invalidate_bank;
logic [31:0] invalidate_generation;
logic [1:0] invalidate_component;
logic invalidate_ready;
logic [7:0] invalidate_error_code;
logic coverage_valid;
logic [3:0] coverage_bank;
logic [1:0] coverage_component;
logic [31:0] coverage_generation;
logic [31:0] coverage_transaction_id;
logic [4:0] coverage_role;
logic coverage_data_complete;
logic coverage_scale_complete;
logic coverage_ready;
logic [7:0] coverage_error_code;
logic embedding_valid;
logic [31:0] embedding_transaction_id;
logic [4:0] embedding_role;
logic [31:0] embedding_generation;
logic [4:0] embedding_row;
logic [1:0] embedding_lane;
logic embedding_ready;
logic [7:0] embedding_error_code;
logic [127:0] program_mem[0:15];
logic [127:0] cmd_pipe;
int accepts[0:3];
logic [31:0] tx[0:3];
logic [11:0] ids[0:3];
logic [95:0] gens[0:3];
logic [14:0] captured_roles[0:3];
logic [2:0] masks[0:3];
logic [1:0] counts[0:3];
logic [3:0] accepted_op[0:3];
logic [111:0] accepted_payload[0:3];
logic [3:0] previous_stall;
logic [2047:0] previous_offer[0:3];
int cycles=0;
int same_edge_checks=0;
logic [2047:0] offered[0:3];
smollm2_isa_dispatcher dispatch(
 .clk(clk),
 .resetn(resetn),
 .start(start),
 .cmd_doutb(cmd_doutb),
 .busy(busy),
 .done(done),
 .error(error),
 .error_code(error_code),
 .current_pc(current_pc),
 .cmd_enb(cmd_enb),
 .cmd_addrb(cmd_addrb),
 .bank_busy(bank_busy),
 .bank_owner_port(bank_owner_port),
 .bank_desc_present(bank_desc_present),
 .bank_profiles(bank_profiles),
 .bank_rows(bank_rows),
 .bank_cols(bank_cols),
 .bank_positions(bank_positions),
 .bank_layers(bank_layers),
 .bank_generations(bank_generations),
 .bank_data_valid(bank_data_valid),
 .bank_scale_valid(bank_scale_valid),
 .bank_b7_static_valid(bank_b7_static_valid),
 .bank_b7_rope_valid(bank_b7_rope_valid),
 .bank_embedding_lanes(bank_embedding_lanes),
 .bank_embedding_lane_valid(bank_embedding_lane_valid),
 .acquire_valid(acquire_valid),
 .acquire_transaction_id(acquire_transaction_id),
 .acquire_used_bank_mask(acquire_used_bank_mask),
 .acquire_bank_ids(acquire_bank_ids),
 .acquire_roles(acquire_roles),
 .acquire_generations(acquire_generations),
 .acquire_ready(acquire_ready),
 .acquire_error_code(acquire_error_code),
 .release_valid(release_valid),
 .release_transaction_id(release_transaction_id),
 .release_used_bank_mask(release_used_bank_mask),
 .release_bank_ids(release_bank_ids),
 .release_roles(release_roles),
 .release_generations(release_generations),
 .release_ready(release_ready),
 .release_error_code(release_error_code),
 .cfg_valid(cfg_valid),
 .cfg_transaction_id(cfg_transaction_id),
 .cfg_bank(cfg_bank),
 .cfg_profile(cfg_profile),
 .cfg_rows(cfg_rows),
 .cfg_cols(cfg_cols),
 .cfg_position(cfg_position),
 .cfg_layer(cfg_layer),
 .cfg_component(cfg_component),
 .cfg_generation(cfg_generation),
 .cfg_resp_ready(cfg_resp_ready),
 .cfg_ready(cfg_ready),
 .cfg_resp_valid(cfg_resp_valid),
 .cfg_resp_transaction_id(cfg_resp_transaction_id),
 .cfg_resp_error_code(cfg_resp_error_code),
 .engine_cmd_ready(engine_cmd_ready),
 .engine_cmd_valid(engine_cmd_valid),
 .engine_cmd_opcode(engine_cmd_opcode),
 .engine_cmd_payload(engine_cmd_payload),
 .engine_cmd_bank_ids(engine_cmd_bank_ids),
 .engine_cmd_transaction_id(engine_cmd_transaction_id),
 .engine_cmd_generations(engine_cmd_generations),
 .engine_cmd_desc_present(engine_cmd_desc_present),
 .engine_cmd_profiles(engine_cmd_profiles),
 .engine_cmd_rows(engine_cmd_rows),
 .engine_cmd_cols(engine_cmd_cols),
 .engine_cmd_positions(engine_cmd_positions),
 .engine_cmd_layers(engine_cmd_layers),
 .engine_cmd_desc_generations(engine_cmd_desc_generations),
 .engine_cmd_data_valid(engine_cmd_data_valid),
 .engine_cmd_scale_valid(engine_cmd_scale_valid),
 .engine_cmd_desc_busy(engine_cmd_desc_busy),
 .engine_cmd_desc_owner(engine_cmd_desc_owner),
 .engine_cmd_b7_static_valid(engine_cmd_b7_static_valid),
 .engine_cmd_embedding_lanes(engine_cmd_embedding_lanes),
 .engine_cmd_embedding_lane_valid(engine_cmd_embedding_lane_valid),
 .engine_resp_valid(engine_resp_valid),
 .engine_resp_transaction_id(engine_resp_transaction_id),
 .engine_resp_used_bank_mask(engine_resp_used_bank_mask),
 .engine_resp_used_bank_count(engine_resp_used_bank_count),
 .engine_resp_bank_ids(engine_resp_bank_ids),
 .engine_resp_generations(engine_resp_generations),
 .engine_resp_error_code(engine_resp_error_code),
 .engine_resp_ready(engine_resp_ready)
);
smollm2_bank_controller banks(
 .clk(clk),
 .resetn(resetn),
 .bank_busy(bank_busy),
 .bank_owner_port(bank_owner_port),
 .bank_desc_present(bank_desc_present),
 .bank_profiles(bank_profiles),
 .bank_rows(bank_rows),
 .bank_cols(bank_cols),
 .bank_positions(bank_positions),
 .bank_layers(bank_layers),
 .bank_generations(bank_generations),
 .bank_data_valid(bank_data_valid),
 .bank_scale_valid(bank_scale_valid),
 .bank_b7_static_valid(bank_b7_static_valid),
 .bank_b7_rope_valid(bank_b7_rope_valid),
 .bank_embedding_lanes(bank_embedding_lanes),
 .bank_embedding_lane_valid(bank_embedding_lane_valid),
 .acquire_valid(acquire_valid),
 .acquire_transaction_id(acquire_transaction_id),
 .acquire_used_bank_mask(acquire_used_bank_mask),
 .acquire_bank_ids(acquire_bank_ids),
 .acquire_roles(acquire_roles),
 .acquire_generations(acquire_generations),
 .acquire_ready(acquire_ready),
 .acquire_error_code(acquire_error_code),
 .release_valid(release_valid),
 .release_transaction_id(release_transaction_id),
 .release_used_bank_mask(release_used_bank_mask),
 .release_bank_ids(release_bank_ids),
 .release_roles(release_roles),
 .release_generations(release_generations),
 .release_ready(release_ready),
 .release_error_code(release_error_code),
 .cfg_valid(cfg_valid),
 .cfg_transaction_id(cfg_transaction_id),
 .cfg_bank(cfg_bank),
 .cfg_profile(cfg_profile),
 .cfg_rows(cfg_rows),
 .cfg_cols(cfg_cols),
 .cfg_position(cfg_position),
 .cfg_layer(cfg_layer),
 .cfg_component(cfg_component),
 .cfg_generation(cfg_generation),
 .cfg_resp_ready(cfg_resp_ready),
 .cfg_ready(cfg_ready),
 .cfg_resp_valid(cfg_resp_valid),
 .cfg_resp_transaction_id(cfg_resp_transaction_id),
 .cfg_resp_error_code(cfg_resp_error_code),
 .producer_valid(producer_valid),
 .producer_transaction_id(producer_transaction_id),
 .producer_role(producer_role),
 .producer_bank(producer_bank),
 .producer_accepted_generation(producer_accepted_generation),
 .producer_generation(producer_generation),
 .producer_profile(producer_profile),
 .producer_rows(producer_rows),
 .producer_cols(producer_cols),
 .producer_position(producer_position),
 .producer_layer(producer_layer),
 .producer_ready(producer_ready),
 .producer_error_code(producer_error_code),
 .invalidate_valid(invalidate_valid),
 .invalidate_transaction_id(invalidate_transaction_id),
 .invalidate_role(invalidate_role),
 .invalidate_bank(invalidate_bank),
 .invalidate_generation(invalidate_generation),
 .invalidate_component(invalidate_component),
 .invalidate_ready(invalidate_ready),
 .invalidate_error_code(invalidate_error_code),
 .coverage_valid(coverage_valid),
 .coverage_bank(coverage_bank),
 .coverage_component(coverage_component),
 .coverage_generation(coverage_generation),
 .coverage_transaction_id(coverage_transaction_id),
 .coverage_role(coverage_role),
 .coverage_data_complete(coverage_data_complete),
 .coverage_scale_complete(coverage_scale_complete),
 .coverage_ready(coverage_ready),
 .coverage_error_code(coverage_error_code),
 .embedding_valid(embedding_valid),
 .embedding_transaction_id(embedding_transaction_id),
 .embedding_role(embedding_role),
 .embedding_generation(embedding_generation),
 .embedding_row(embedding_row),
 .embedding_lane(embedding_lane),
 .embedding_ready(embedding_ready),
 .embedding_error_code(embedding_error_code)
);
always #2.5 clk=~clk;
always_ff @(posedge clk) begin
 if (cmd_enb) cmd_pipe<=program_mem[cmd_addrb];
 cmd_doutb<=cmd_pipe;
end
always_comb begin
 for(int s=0;s<4;s++) offered[s]={engine_cmd_opcode[s*4+:4],engine_cmd_payload[s*112+:112],engine_cmd_bank_ids[s*12+:12],engine_cmd_transaction_id[s*32+:32],engine_cmd_generations[s*96+:96],engine_cmd_desc_present[s*3+:3],engine_cmd_profiles[s*15+:15],engine_cmd_rows[s*33+:33],engine_cmd_cols[s*48+:48],engine_cmd_positions[s*30+:30],engine_cmd_layers[s*15+:15],engine_cmd_desc_generations[s*96+:96],engine_cmd_data_valid[s*3+:3],engine_cmd_scale_valid[s*3+:3],engine_cmd_desc_busy[s*3+:3],engine_cmd_desc_owner[s*15+:15],engine_cmd_b7_static_valid[s],engine_cmd_embedding_lanes[s*64+:64],engine_cmd_embedding_lane_valid[s*32+:32]};
end
always @(posedge clk) begin
 cycles=cycles+1;
 if(cycles>30000) $fatal(1,"AUDIT timeout");
 if(resetn) begin
  if (acquire_valid !== (|(engine_cmd_valid & engine_cmd_ready))) $fatal(1,"acquire not same edge as engine accept");
  for(int s=0;s<4;s++) begin
   if(previous_stall[s] && (!engine_cmd_valid[s] || offered[s]!==previous_offer[s])) $fatal(1,"stalled offer withdrawn/changed slot%0d",s);
   previous_stall[s]=engine_cmd_valid[s]&&!engine_cmd_ready[s];previous_offer[s]=offered[s];
   if(engine_cmd_valid[s]&&engine_cmd_ready[s]) begin
    if(!acquire_ready || acquire_error_code!=0) $fatal(1,"accepted engine without atomic acquisition");
    if(engine_cmd_opcode[s*4+:4]!==program_mem[current_pc][127:124]||engine_cmd_payload[s*112+:112]!==program_mem[current_pc][111:0]||engine_cmd_bank_ids[s*12+:12]!=={program_mem[current_pc][115:112],program_mem[current_pc][119:116],program_mem[current_pc][123:120]})$fatal(1,"raw record routing mismatch");
    for(int p=0;p<3;p++)if(acquire_used_bank_mask[p]&&bank_busy[acquire_bank_ids[p*4+:4]])$fatal(1,"partial/preexisting ownership on commandaccept");
    same_edge_checks=same_edge_checks+1;
    accepts[s]=accepts[s]+1;tx[s]=engine_cmd_transaction_id[s*32+:32];ids[s]=engine_cmd_bank_ids[s*12+:12];gens[s]=engine_cmd_generations[s*96+:96];masks[s]=acquire_used_bank_mask;captured_roles[s]=acquire_roles;counts[s]=2'(int'(acquire_used_bank_mask[0])+int'(acquire_used_bank_mask[1])+int'(acquire_used_bank_mask[2]));accepted_op[s]=engine_cmd_opcode[s*4+:4];accepted_payload[s]=engine_cmd_payload[s*112+:112];
    if (acquire_transaction_id!==tx[s]||acquire_bank_ids!==ids[s]||acquire_generations!==gens[s]) $fatal(1,"acquire identity differs");
   end
  end
 end else previous_stall=0;
end
task automatic ticks(input int n);repeat(n) @(negedge clk);endtask
task automatic reset_all;
 resetn=0;start=0;engine_cmd_ready=0;engine_resp_valid=0;engine_resp_transaction_id=0;engine_resp_used_bank_mask=0;engine_resp_used_bank_count=0;engine_resp_bank_ids=0;engine_resp_generations=0;engine_resp_error_code=0;
 producer_valid=0;
 producer_transaction_id=0;
 producer_role=0;
 producer_bank=0;
 producer_accepted_generation=0;
 producer_generation=0;
 producer_profile=0;
 producer_rows=0;
 producer_cols=0;
 producer_position=0;
 producer_layer=0;
 invalidate_valid=0;
 invalidate_transaction_id=0;
 invalidate_role=0;
 invalidate_bank=0;
 invalidate_generation=0;
 invalidate_component=0;
 coverage_valid=0;
 coverage_bank=0;
 coverage_component=0;
 coverage_generation=0;
 coverage_transaction_id=0;
 coverage_role=0;
 coverage_data_complete=0;
 coverage_scale_complete=0;
 embedding_valid=0;
 embedding_transaction_id=0;
 embedding_role=0;
 embedding_generation=0;
 embedding_row=0;
 embedding_lane=0;
 for(int s=0;s<4;s++)begin accepts[s]=0;tx[s]=0;ids[s]=0;gens[s]=0;masks[s]=0;counts[s]=0;end
 ticks(4);resetn=1;ticks(2);
 if(bank_busy!=0||bank_desc_present!=0) $fatal(1,"reset leaked metadata");
endtask
task automatic launch(input string name);
 $readmemh({"audit_",name,".hex"},program_mem);
 @(negedge clk);start=1;@(negedge clk);start=0;
endtask
task automatic accepted(input int s,input int n);
 int t;t=0;
 while(accepts[s]<n && t<3000)begin ticks(1);t++;end
 if(accepts[s]!=n) $fatal(1,"missing acceptance slot%0d target%0d actual%0d pc%0d err%0h",s,n,accepts[s],current_pc,error_code);
 for(int p=0;p<3;p++)if(masks[s][p])begin
  if(!bank_busy[ids[s][p*4+:4]]||bank_owner_port[ids[s][p*4+:4]*5+:5]!==captured_roles[s][p*5+:5])$fatal(1,"accepted bank not owned by expected role");
 end
endtask
task automatic response(input int s,input bit bad,input logic[7:0] ec);
 engine_resp_transaction_id[s*32+:32]=tx[s]+(bad?32'd1:32'd0);
 engine_resp_used_bank_mask[s*3+:3]=masks[s];engine_resp_used_bank_count[s*2+:2]=counts[s];engine_resp_bank_ids[s*12+:12]=ids[s];engine_resp_generations[s*96+:96]=gens[s];engine_resp_error_code[s*8+:8]=ec;engine_resp_valid[s]=1;
 do @(posedge clk);while(!engine_resp_ready[s]);@(negedge clk);engine_resp_valid[s]=0;
endtask
task automatic terminal(input bit want_error,input logic[7:0] code);
 int t;t=0;while((busy||!(done||error))&&t<3000)begin ticks(1);t++;end
 if(want_error)begin if(!error||error_code!==code)$fatal(1,"expected error%0h got%0h done%0b",code,error_code,done);end
 else if(!done||error)$fatal(1,"expected done err%0h",error_code);
 if(bank_busy!=0)$fatal(1,"terminal with ownership");
endtask
task automatic begin_quant;
 producer_valid=1;producer_transaction_id=tx[3];producer_role=23;producer_bank=13;producer_accepted_generation=gens[3][64+:32];producer_generation=producer_accepted_generation+1;producer_profile=21;producer_rows=1;producer_cols=576;producer_position=0;producer_layer=0;
 do @(posedge clk);while(!producer_ready);if(producer_error_code!=0)$fatal(1,"producer rejected%0h",producer_error_code);@(negedge clk);producer_valid=0;
 if(bank_generations[13*32+:32]!=producer_generation)$fatal(1,"producer generation not live");
endtask
task automatic coverage_quant;
 coverage_valid=1;coverage_bank=13;coverage_component=0;coverage_generation=producer_generation;coverage_transaction_id=tx[3];coverage_role=23;coverage_data_complete=1;coverage_scale_complete=1;
 do @(posedge clk);while(!coverage_ready);@(negedge clk);coverage_valid=0;
endtask
task automatic coverage_b7(input logic[1:0] component,input logic[31:0] generation);
 coverage_valid=1;coverage_bank=7;coverage_component=component;coverage_generation=generation;coverage_transaction_id=tx[0];coverage_role=1;coverage_data_complete=1;coverage_scale_complete=0;
 do @(posedge clk);while(!coverage_ready);@(negedge clk);coverage_valid=0;
endtask
initial begin
 clk=0;cmd_doutb=0;cmd_pipe=0;
 // Alternate weight DMA accepts while GEMM is outstanding; blocked next PC still collects completions.
 reset_all();engine_cmd_ready=4'b1111;launch("concurrent");accepted(2,1);accepted(0,1);
 if(ids[0][3:0]!=15||!bank_busy[13]||!bank_busy[3]||!bank_busy[1])$fatal(1,"concurrency fixture wrong");
 ticks(30);if(accepts[0]!=1||current_pc!=6)$fatal(1,"lookahead/blocked PC violated");
 response(0,0,0);ticks(4);if(bank_busy[15]||!bank_busy[13])$fatal(1,"DMA release disturbed GEMM");
 response(2,0,0);accepted(0,2);response(0,0,0);terminal(0,0);
 // FENCE drains before issue and START preserves prior descriptors/global transaction IDs.
 begin logic[31:0] prior_tx;prior_tx=tx[0];launch("fence");accepted(0,3);if(tx[0]<=prior_tx||!bank_desc_present[13])$fatal(1,"START reset transaction/descriptors");ticks(20);if(current_pc!=1||accepts[0]!=3)$fatal(1,"FENCE failed drain");response(0,0,0);accepted(0,4);response(0,0,0);terminal(0,0);end
 // DQ/QUANT ignored bank1 aliases real bank0; producer destination absent/gen0 is legal.
 reset_all();engine_cmd_ready=4'b0111;launch("quant");
 while(!engine_cmd_valid[3])ticks(1);ticks(15);if(bank_busy!=0)$fatal(1,"stalled command prematurely acquired");engine_cmd_ready[3]=1;accepted(3,1);
 if(masks[3]!=3'b101||ids[3]!=12'hd02||bank_busy[2]!=1||bank_busy[13]!=1)$fatal(1,"conditional mask101 broken");
 begin_quant();coverage_quant();if(!bank_data_valid[13]||!bank_scale_valid[13])$fatal(1,"coverage not published");response(3,0,0);terminal(0,0);
 launch("dq");accepted(3,2);if(masks[3]!=3'b101||ids[3]!=12'h003||bank_generations[13*32+:32]!=1)$fatal(1,"DQ mask/gen mismatch");response(3,0,0);terminal(0,0);
 // Authenticated invalidate is sticky: later complete event cannot resurrect the same epoch.
 reset_all();engine_cmd_ready=15;launch("quant");accepted(3,1);begin_quant();
 invalidate_valid=1;invalidate_transaction_id=tx[3];invalidate_role=23;invalidate_bank=13;invalidate_generation=producer_generation;
 do @(posedge clk);while(!invalidate_ready);if(invalidate_error_code!=0)$fatal(1,"invalidate rejected");@(negedge clk);invalidate_valid=0;
 coverage_quant();if(bank_data_valid[13]||bank_scale_valid[13])$fatal(1,"late coverage resurrected invalid epoch");response(3,0,8'h05);terminal(1,8'h05);
 // B7 component generations differ; abort preserves the independently resident component.
 for(int c=1;c<=2;c++)begin
  reset_all();engine_cmd_ready=15;launch("b7");accepted(0,1);
  if(gens[0][31:0]!=2||bank_generations[224+:32]!=2)$fatal(1,"B7 generation max");
  coverage_b7(1,2);coverage_b7(2,1);
  if(!bank_b7_rope_valid||!bank_b7_static_valid)$fatal(1,"B7 coverage setup");
  invalidate_valid=1;invalidate_transaction_id=tx[0];invalidate_role=1;invalidate_bank=7;invalidate_component=2'(c);invalidate_generation=c==1?2:1;
  do @(posedge clk);while(!invalidate_ready);if(invalidate_error_code!=0)$fatal(1,"B7 targeted invalidate rejected");@(negedge clk);invalidate_valid=0;
  coverage_b7(2'(c),c==1?2:1);
  if((c==1&&(bank_b7_rope_valid||!bank_b7_static_valid))||(c==2&&(!bank_b7_rope_valid||bank_b7_static_valid)))$fatal(1,"B7 target abort/late coverage affected peer");
  response(0,0,8'h05);terminal(1,8'h05);
 end
 // Wrong response changes no owners; real response must still drain under sticky07.
 reset_all();engine_cmd_ready=15;launch("bad");accepted(2,1);
 begin logic[15:0] owners;owners=bank_busy;response(2,1,0);ticks(8);if(bank_busy!==owners)$fatal(1,"bad response released");if(!busy||done)$fatal(1,"terminal before real match");response(2,0,0);terminal(1,8'h07);end
 // Duplicate after a completed independent DMA cannot release another outstanding command.
 reset_all();engine_cmd_ready=15;launch("concurrent");accepted(2,1);accepted(0,1);response(0,0,0);ticks(5);response(0,0,0);ticks(5);
 if(!bank_busy[13]||!bank_busy[3]||!bank_busy[1]||done||!busy)$fatal(1,"duplicate disturbed outstanding");response(2,0,0);terminal(1,8'h07);
 // Sticky error stops new offers but retains the already presented stalled DMA offer.
 reset_all();engine_cmd_ready=4'b1110;launch("retained");accepted(2,1);while(!engine_cmd_valid[0])ticks(1);ticks(5);response(2,1,0);ticks(7);
 if(!engine_cmd_valid[0]||bank_busy[15])$fatal(1,"retained stalled offer broken");engine_cmd_ready[0]=1;accepted(0,1);response(2,0,0);response(0,0,0);terminal(1,8'h07);
 // Coordinated reset clears active ownership and a stalled captured offer in both modules.
 reset_all();engine_cmd_ready=15;launch("bad");accepted(2,1);reset_all();
 engine_cmd_ready=7;launch("quant");while(!engine_cmd_valid[3])ticks(1);ticks(5);reset_all();ticks(5);if(engine_cmd_valid!=0||bank_busy!=0||busy)$fatal(1,"live reset leaked command/owners");
 // Every descending-flat logical bank slice maps the copied ascending ownership table correctly.
 reset_all();engine_cmd_ready=15;launch("orientation0");
 for(int b=0;b<15;b++)begin
  accepted(0,b+1);if(bank_busy!==(16'b1<<b)||bank_owner_port[b*5+:5]!=1||ids[0][3:0]!=4'(b))$fatal(1,"bank orientation%0d",b);
  response(0,0,0);
 end
 terminal(0,0);launch("orientation1");accepted(0,16);if(bank_busy!==16'h8000||bank_owner_port[75+:5]!=1)$fatal(1,"bank orientation15");response(0,0,0);terminal(0,0);
 reset_all();engine_cmd_ready=15;launch("unsupported");terminal(1,8'h01);if(same_edge_checks<10)$fatal(1,"vacuous checks");
 $display("AUDIT_CONTROL_INTEGRATION_PASS same_edge=%0d cycles=%0d",same_edge_checks,cycles);$finish;
end
endmodule
