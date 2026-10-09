`timescale 1ns/1ps
module dispatcher_tb;
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
logic [3:0] engine_cmd_ready;
logic [3:0] engine_resp_valid;
logic [127:0] engine_resp_transaction_id;
logic [11:0] engine_resp_used_bank_mask;
logic [7:0] engine_resp_used_bank_count;
logic [47:0] engine_resp_bank_ids;
logic [383:0] engine_resp_generations;
logic [31:0] engine_resp_error_code;
logic [3:0] engine_resp_ready;
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
smollm2_isa_dispatcher dut(.clk(clk),.resetn(resetn),.start(start),.cmd_doutb(cmd_doutb),.busy(busy),.done(done),.error(error),.error_code(error_code),.current_pc(current_pc),.cmd_enb(cmd_enb),.cmd_addrb(cmd_addrb),.engine_cmd_valid(engine_cmd_valid),.engine_cmd_opcode(engine_cmd_opcode),.engine_cmd_payload(engine_cmd_payload),.engine_cmd_bank_ids(engine_cmd_bank_ids),.engine_cmd_transaction_id(engine_cmd_transaction_id),.engine_cmd_generations(engine_cmd_generations),.engine_cmd_desc_present(engine_cmd_desc_present),.engine_cmd_profiles(engine_cmd_profiles),.engine_cmd_rows(engine_cmd_rows),.engine_cmd_cols(engine_cmd_cols),.engine_cmd_positions(engine_cmd_positions),.engine_cmd_layers(engine_cmd_layers),.engine_cmd_desc_generations(engine_cmd_desc_generations),.engine_cmd_data_valid(engine_cmd_data_valid),.engine_cmd_scale_valid(engine_cmd_scale_valid),.engine_cmd_desc_busy(engine_cmd_desc_busy),.engine_cmd_desc_owner(engine_cmd_desc_owner),.engine_cmd_b7_static_valid(engine_cmd_b7_static_valid),.engine_cmd_embedding_lanes(engine_cmd_embedding_lanes),.engine_cmd_embedding_lane_valid(engine_cmd_embedding_lane_valid),.engine_cmd_ready(engine_cmd_ready),.engine_resp_valid(engine_resp_valid),.engine_resp_transaction_id(engine_resp_transaction_id),.engine_resp_used_bank_mask(engine_resp_used_bank_mask),.engine_resp_used_bank_count(engine_resp_used_bank_count),.engine_resp_bank_ids(engine_resp_bank_ids),.engine_resp_generations(engine_resp_generations),.engine_resp_error_code(engine_resp_error_code),.engine_resp_ready(engine_resp_ready),.bank_busy(bank_busy),.bank_owner_port(bank_owner_port),.bank_desc_present(bank_desc_present),.bank_profiles(bank_profiles),.bank_rows(bank_rows),.bank_cols(bank_cols),.bank_positions(bank_positions),.bank_layers(bank_layers),.bank_generations(bank_generations),.bank_data_valid(bank_data_valid),.bank_scale_valid(bank_scale_valid),.bank_b7_static_valid(bank_b7_static_valid),.bank_b7_rope_valid(bank_b7_rope_valid),.bank_embedding_lanes(bank_embedding_lanes),.bank_embedding_lane_valid(bank_embedding_lane_valid),.acquire_valid(acquire_valid),.acquire_transaction_id(acquire_transaction_id),.acquire_used_bank_mask(acquire_used_bank_mask),.acquire_bank_ids(acquire_bank_ids),.acquire_roles(acquire_roles),.acquire_generations(acquire_generations),.acquire_ready(acquire_ready),.acquire_error_code(acquire_error_code),.release_valid(release_valid),.release_transaction_id(release_transaction_id),.release_used_bank_mask(release_used_bank_mask),.release_bank_ids(release_bank_ids),.release_roles(release_roles),.release_generations(release_generations),.release_ready(release_ready),.release_error_code(release_error_code),.cfg_valid(cfg_valid),.cfg_transaction_id(cfg_transaction_id),.cfg_bank(cfg_bank),.cfg_profile(cfg_profile),.cfg_rows(cfg_rows),.cfg_cols(cfg_cols),.cfg_position(cfg_position),.cfg_layer(cfg_layer),.cfg_component(cfg_component),.cfg_generation(cfg_generation),.cfg_resp_ready(cfg_resp_ready),.cfg_ready(cfg_ready),.cfg_resp_valid(cfg_resp_valid),.cfg_resp_transaction_id(cfg_resp_transaction_id),.cfg_resp_error_code(cfg_resp_error_code));
initial begin
 resetn=0;
 start=0;
 cmd_doutb=0;
 engine_cmd_ready=0;
 engine_resp_valid=0;
 engine_resp_transaction_id=0;
 engine_resp_used_bank_mask=0;
 engine_resp_used_bank_count=0;
 engine_resp_bank_ids=0;
 engine_resp_generations=0;
 engine_resp_error_code=0;
 bank_busy=0;
 bank_owner_port=0;
 bank_desc_present=0;
 bank_profiles=0;
 bank_rows=0;
 bank_cols=0;
 bank_positions=0;
 bank_layers=0;
 bank_generations=0;
 bank_data_valid=0;
 bank_scale_valid=0;
 bank_b7_static_valid=0;
 bank_b7_rope_valid=0;
 bank_embedding_lanes=0;
 bank_embedding_lane_valid=0;
 acquire_ready=0;
 acquire_error_code=0;
 release_ready=0;
 release_error_code=0;
 cfg_ready=0;
 cfg_resp_valid=0;
 cfg_resp_transaction_id=0;
 cfg_resp_error_code=0;
end
logic[127:0]program_mem[0:15],pipe0_r;always #2.5 clk=~clk;initial clk=0;
always @(posedge clk)begin if(cmd_enb)pipe0_r<=program_mem[cmd_addrb];cmd_doutb<=pipe0_r;end
localparam integer VECTOR_COUNT=2957;
logic[127:0]decode_records[0:VECTOR_COUNT-1];logic[0:0]decode_expect[0:VECTOR_COUNT-1];
 logic[3:0]ready_mask,allow_response,model_pending_r,zero_response;
 logic[31:0]model_txn_r[0:3];logic[11:0]model_ids_r[0:3];logic[95:0]model_gens_r[0:3];
 logic[2:0]model_mask_r[0:3];logic[1:0]model_count_r[0:3];integer delay_r[0:3];
 logic[31:0]owner_txn_r[0:15],owner_gen_r[0:15];
 logic release_enable,cfg_enable,random_mode;
 logic inject_valid;logic[1:0]inject_slot;logic[31:0]inject_txn;logic[11:0]inject_ids;
 logic[95:0]inject_gens;logic[2:0]inject_mask;logic[1:0]inject_count;logic[7:0]inject_error;
 integer cycle_r,accepts_r,cfg_accepts_r,releases_r,last_txn_r,concurrency_r;
 logic[31:0]rng_r;logic[3:0]hold_cmd_r;logic[2467:0]prev_cmd_r;
 wire[2467:0]command_bundle={engine_cmd_opcode,engine_cmd_payload,engine_cmd_bank_ids,engine_cmd_transaction_id,
  engine_cmd_generations,engine_cmd_desc_present,engine_cmd_profiles,engine_cmd_rows,engine_cmd_cols,
  engine_cmd_positions,engine_cmd_layers,engine_cmd_desc_generations,engine_cmd_data_valid,
  engine_cmd_scale_valid,engine_cmd_desc_busy,engine_cmd_desc_owner,engine_cmd_b7_static_valid,engine_cmd_embedding_lanes,engine_cmd_embedding_lane_valid};
 logic cfg_hold_r,release_hold_r;logic[116:0]cfg_prev_r;logic[157:0]release_prev_r;
 wire[116:0]cfg_bundle={cfg_transaction_id,cfg_bank,cfg_profile,cfg_rows,cfg_cols,cfg_position,cfg_layer,cfg_component,cfg_generation};
 wire[157:0]release_bundle={release_transaction_id,release_used_bank_mask,release_bank_ids,release_roles,release_generations};
 // Model owns exact control transactions only. It does not model tensor reads,
 // coverage or DMA transport; clean completions stand for quiescent engines.
 always_comb begin
  acquire_ready=1;acquire_error_code=0;
  for(integer n=0;n<3;n=n+1)if(acquire_used_bank_mask[n])begin
   if(bank_busy[acquire_bank_ids[n*4+:4]])acquire_ready=0;
   if(acquire_generations[n*32+:32]!=bank_generations[acquire_bank_ids[n*4+:4]*32+:32])begin acquire_ready=0;acquire_error_code=7;end
  end
  release_ready=release_enable;release_error_code=0;
  for(integer n=0;n<3;n=n+1)if(release_used_bank_mask[n])begin
   if(!bank_busy[release_bank_ids[n*4+:4]]||bank_owner_port[release_bank_ids[n*4+:4]*5+:5]!=release_roles[n*5+:5]||
    owner_txn_r[release_bank_ids[n*4+:4]]!=release_transaction_id||owner_gen_r[release_bank_ids[n*4+:4]]!=release_generations[n*32+:32])release_error_code=7;
  end
  cfg_ready=cfg_enable&&!bank_busy[cfg_bank];
  engine_cmd_ready=ready_mask;
  if(random_mode)engine_cmd_ready=ready_mask&rng_r[3:0];
  engine_resp_valid=0;engine_resp_transaction_id=0;engine_resp_used_bank_mask=0;
  engine_resp_used_bank_count=0;engine_resp_bank_ids=0;engine_resp_generations=0;engine_resp_error_code=0;
  for(integer s=0;s<4;s=s+1)begin
   engine_resp_valid[s]=model_pending_r[s]&&allow_response[s]&&delay_r[s]==0;
   engine_resp_transaction_id[s*32+:32]=model_txn_r[s];engine_resp_used_bank_mask[s*3+:3]=model_mask_r[s];
   engine_resp_used_bank_count[s*2+:2]=model_count_r[s];engine_resp_bank_ids[s*12+:12]=model_ids_r[s];engine_resp_generations[s*96+:96]=model_gens_r[s];
   if(zero_response[s]&&engine_cmd_valid[s]&&engine_cmd_ready[s])begin
    engine_resp_valid[s]=1;engine_resp_transaction_id[s*32+:32]=engine_cmd_transaction_id[s*32+:32];
    engine_resp_used_bank_mask[s*3+:3]=engine_cmd_desc_busy[s*3+:3];
    engine_resp_used_bank_count[s*2+:2]={1'b0,engine_cmd_desc_busy[s*3]}+{1'b0,engine_cmd_desc_busy[s*3+1]}+{1'b0,engine_cmd_desc_busy[s*3+2]};
    engine_resp_bank_ids[s*12+:12]=engine_cmd_bank_ids[s*12+:12];engine_resp_generations[s*96+:96]=engine_cmd_generations[s*96+:96];
   end
  end
  if(inject_valid)begin
   engine_resp_valid[inject_slot]=1;engine_resp_transaction_id[inject_slot*32+:32]=inject_txn;
   engine_resp_used_bank_mask[inject_slot*3+:3]=inject_mask;engine_resp_used_bank_count[inject_slot*2+:2]=inject_count;
   engine_resp_bank_ids[inject_slot*12+:12]=inject_ids;engine_resp_generations[inject_slot*96+:96]=inject_gens;
   engine_resp_error_code[inject_slot*8+:8]=inject_error;
  end
 end
 always @(posedge clk)begin
  if(!resetn)begin
   cycle_r<=0;accepts_r<=0;cfg_accepts_r<=0;releases_r<=0;last_txn_r<=0;concurrency_r<=0;rng_r<=32'h12572639;
   bank_busy<=0;bank_owner_port<=0;bank_desc_present<=16'hffff;bank_profiles<=0;bank_rows<=0;bank_cols<=0;bank_positions<=0;bank_layers<=0;
   bank_data_valid<=16'hffff;bank_scale_valid<=16'hffff;bank_b7_static_valid<=1;bank_b7_rope_valid<=1;
   bank_embedding_lanes<=64'h1be41be41be41be4;bank_embedding_lane_valid<=32'hffffffff;
   cfg_resp_valid<=0;cfg_resp_transaction_id<=0;cfg_resp_error_code<=0;
   model_pending_r<=0;hold_cmd_r<=0;prev_cmd_r<=0;cfg_hold_r<=0;release_hold_r<=0;cfg_prev_r<=0;release_prev_r<=0;
   for(integer n=0;n<16;n=n+1)begin bank_generations[n*32+:32]<=32'(n+1);owner_txn_r[n]<=0;owner_gen_r[n]<=0;end
   for(integer s=0;s<4;s=s+1)begin model_txn_r[s]<=0;model_ids_r[s]<=0;model_gens_r[s]<=0;model_mask_r[s]<=0;model_count_r[s]<=0;delay_r[s]<=0;end
  end else begin
   cycle_r<=cycle_r+1;rng_r<={rng_r[30:0],rng_r[31]^rng_r[21]^rng_r[1]^rng_r[0]};
   if(hold_cmd_r!=0&&(engine_cmd_valid&hold_cmd_r)!=hold_cmd_r)$fatal(1,"engine valid withdrawn");
   if(hold_cmd_r!=0&&command_bundle!==prev_cmd_r)$fatal(1,"engine snapshot changed during stall");
   hold_cmd_r<=engine_cmd_valid&~engine_cmd_ready;prev_cmd_r<=command_bundle;
   if(cfg_hold_r&&(!cfg_valid||cfg_bundle!==cfg_prev_r))$fatal(1,"cfg offer changed");
   cfg_hold_r<=cfg_valid&&!cfg_ready;cfg_prev_r<=cfg_bundle;
   if(release_hold_r&&(!release_valid||release_bundle!==release_prev_r))$fatal(1,"release offer changed");
   release_hold_r<=release_valid&&!release_ready;release_prev_r<=release_bundle;
   if(acquire_valid)begin
    if(!acquire_ready||acquire_error_code!=0)$fatal(1,"accepted engine without atomic eligible acquisition");
    if((engine_cmd_valid&engine_cmd_ready)==0)$fatal(1,"acquire without engine acceptance");
    for(integer n=0;n<3;n=n+1)if(acquire_used_bank_mask[n])begin
     if(bank_busy[acquire_bank_ids[n*4+:4]])$fatal(1,"occupied bank acquisition");
     bank_busy[acquire_bank_ids[n*4+:4]]<=1;
     bank_owner_port[acquire_bank_ids[n*4+:4]*5+:5]<=acquire_roles[n*5+:5];
     owner_txn_r[acquire_bank_ids[n*4+:4]]<=acquire_transaction_id;owner_gen_r[acquire_bank_ids[n*4+:4]]<=acquire_generations[n*32+:32];
    end
   end
   if(release_valid&&release_ready&&release_error_code==0)begin
    releases_r<=releases_r+1;
    for(integer n=0;n<3;n=n+1)if(release_used_bank_mask[n])begin bank_busy[release_bank_ids[n*4+:4]]<=0;bank_owner_port[release_bank_ids[n*4+:4]*5+:5]<=0;end
   end
   if(cfg_resp_valid&&cfg_resp_ready)cfg_resp_valid<=0;
   if(cfg_valid&&cfg_ready)begin
    if(cfg_transaction_id<=32'(last_txn_r))$fatal(1,"config transaction reused across START");
    last_txn_r<=int'(cfg_transaction_id);cfg_accepts_r<=cfg_accepts_r+1;
    bank_generations[cfg_bank*32+:32]<=cfg_generation;bank_profiles[cfg_bank*5+:5]<=cfg_profile;
    bank_rows[cfg_bank*11+:11]<=cfg_rows;bank_cols[cfg_bank*16+:16]<=cfg_cols;
    bank_positions[cfg_bank*10+:10]<=cfg_position;bank_layers[cfg_bank*5+:5]<=cfg_layer;bank_desc_present[cfg_bank]<=1;
    cfg_resp_valid<=1;cfg_resp_transaction_id<=cfg_transaction_id;cfg_resp_error_code<=0;
   end
   for(integer s=0;s<4;s=s+1)begin
    if(model_pending_r[s]&&delay_r[s]>0)delay_r[s]<=delay_r[s]-1;
    if(engine_resp_valid[s]&&engine_resp_ready[s]&&engine_resp_transaction_id[s*32+:32]==model_txn_r[s]&&
      engine_resp_used_bank_mask[s*3+:3]==model_mask_r[s]&&engine_resp_used_bank_count[s*2+:2]==model_count_r[s]&&
      engine_resp_bank_ids[s*12+:12]==model_ids_r[s]&&engine_resp_generations[s*96+:96]==model_gens_r[s])model_pending_r[s]<=0;
    if(engine_cmd_valid[s]&&engine_cmd_ready[s])begin
     if(model_pending_r[s])$fatal(1,"engine slot overlap");
     if(engine_cmd_transaction_id[s*32+:32]<=32'(last_txn_r))$fatal(1,"engine transaction reused across START");
     last_txn_r<=int'(engine_cmd_transaction_id[s*32+:32]);accepts_r<=accepts_r+1;
     model_pending_r[s]<=!(zero_response[s]&&engine_resp_ready[s]);delay_r[s]<=random_mode?int'(rng_r[11:4]):10;
     model_txn_r[s]<=engine_cmd_transaction_id[s*32+:32];model_ids_r[s]<=engine_cmd_bank_ids[s*12+:12];model_gens_r[s]<=engine_cmd_generations[s*96+:96];
     model_mask_r[s]<=engine_cmd_desc_busy[s*3+:3];model_count_r[s]<={1'b0,engine_cmd_desc_busy[s*3]}+{1'b0,engine_cmd_desc_busy[s*3+1]}+{1'b0,engine_cmd_desc_busy[s*3+2]};
     if((|model_pending_r)&&s==0)concurrency_r<=concurrency_r+1;
    end
   end
  end
 end
 task automatic tick(input integer n);repeat(n)begin @(posedge clk);#1;end endtask
 task automatic clear_program;for(integer n=0;n<16;n=n+1)program_mem[n]=0;endtask
 task automatic launch;@(negedge clk);start=1;tick(1);@(negedge clk);start=0;endtask
 task automatic wait_finished;
  integer n;begin n=0;while(busy||(!done&&!error))begin tick(1);n=n+1;if(n>20000)$fatal(1,"completion timeout pc%0d active%h error%h",current_pc,dut.active_r,error_code);end end
 endtask
 task automatic reset_model;begin @(negedge clk);resetn=0;start=0;ready_mask=15;allow_response=15;zero_response=0;release_enable=1;cfg_enable=1;inject_valid=0;random_mode=0;tick(3);@(negedge clk);resetn=1;tick(1);end endtask
 task automatic wait_offer(input integer s);integer n;begin n=0;while(!engine_cmd_valid[s])begin tick(1);n=n+1;if(n>1000)$fatal(1,"offer timeout slot%0d",s);end end endtask
 task automatic inject_response(input integer s,input integer bad);
  begin @(negedge clk);inject_slot=2'(s);inject_txn=model_txn_r[s];inject_ids=model_ids_r[s];inject_gens=model_gens_r[s];inject_mask=model_mask_r[s];inject_count=model_count_r[s];inject_error=0;
   case(bad)1:inject_txn=inject_txn+1;2:inject_mask=inject_mask^1;3:inject_count=inject_count^1;4:inject_ids=inject_ids^1;5:inject_gens=inject_gens^1;6:inject_error=5;default:begin end endcase
   inject_valid=1;while(!engine_resp_ready[s])tick(1);tick(1);@(negedge clk);inject_valid=0;
  end
 endtask
 localparam logic[127:0] GEMM=128'h3d3100000000000000000120000a4040;
 localparam logic[127:0] GEMM15=128'h3df100000000000000000120000a4040;
 localparam logic[127:0] LOAD15=128'h1f000000000000002000002000000000;
 localparam logic[127:0] STORE0=128'h20000000000000002000004000000000;
 localparam logic[127:0] QUANT_K=128'hd5780000000000000000000000200202;
 localparam logic[127:0] QUANT_A=128'hd20d0000000000000000000003002278;
 localparam logic[127:0] DQ=128'he3000000000000000000000001200200;
 localparam logic[127:0] CONFIG15=128'hff000000000000000064000002400804;
 localparam logic[127:0] FENCE=128'hb0000000000000000000000000000000;
 integer before_count,k,scenarios;logic[15:0]oldbusy;integer release_before;
 initial begin
  scenarios=0;ready_mask=15;allow_response=15;zero_response=0;release_enable=1;cfg_enable=1;inject_valid=0;random_mode=0;
  $readmemh("decode_records.hex",decode_records);$readmemh("decode_expect.hex",decode_expect);
  reset_model();clear_program();
  for(integer v=0;v<VECTOR_COUNT;v=v+1)begin
   clear_program();program_mem[0]=decode_records[v];before_count=accepts_r+cfg_accepts_r;
   launch();wait_finished();
   if(decode_expect[v])begin
    if(error)$fatal(1,"codec legal rejected vector%0d record%h error%0d",v,decode_records[v],error_code);
    if(decode_records[v][127:124]!=0&&decode_records[v][127:124]!=11&&accepts_r+cfg_accepts_r!=before_count+1)$fatal(1,"legal vector no acceptance %0d",v);
   end else begin
    if(!error||accepts_r+cfg_accepts_r!=before_count)$fatal(1,"codec illegal issued vector%0d record%h",v,decode_records[v]);
   end
  end
  $display("DISPATCHER_STATIC_PASS vectors=%0d",VECTOR_COUNT);
  reset_model();clear_program();allow_response=0;
  program_mem[0]=GEMM;program_mem[1]=LOAD15;program_mem[2]=STORE0;program_mem[3]=QUANT_K;program_mem[4]=FENCE;program_mem[5]=CONFIG15;
  launch();k=0;while(accepts_r<4)begin tick(1);k=k+1;if(k>200)$fatal(1,"concurrent offers blocked");end
  tick(20);if(current_pc!=4||cfg_accepts_r!=0||done||dut.active_r!=15)$fatal(1,"FENCE did not retain all4 slots");
  @(negedge clk);release_enable=0;inject_response(3,0);tick(5);if(!release_valid||release_transaction_id!=model_txn_r[3])$fatal(1,"release not queued");
  inject_response(0,0);tick(10);if(release_transaction_id!=model_txn_r[3])$fatal(1,"release priority preempted held lower slot");
  @(negedge clk);release_enable=1;allow_response=15;wait_finished();if(error||releases_r!=4||cfg_accepts_r!=1||concurrency_r<1)$fatal(1,"concurrent drain failed");
  scenarios=scenarios+1;$display("DISPATCHER_SCENARIO_PASS concurrent4_fence_config");
  reset_model();clear_program();allow_response=0;
  program_mem[0]=LOAD15;program_mem[1]=GEMM15;program_mem[2]=STORE0;launch();tick(80);
  if(accepts_r!=1||current_pc!=1||engine_cmd_valid!=0)$fatal(1,"blocked PC looked ahead");
  @(negedge clk);allow_response=15;wait_finished();if(error||accepts_r!=3)$fatal(1,"blocked PC failed retry");
  scenarios=scenarios+1;$display("DISPATCHER_SCENARIO_PASS strict_no_lookahead");
  for(integer bad=1;bad<=5;bad=bad+1)begin
   reset_model();clear_program();allow_response=0;program_mem[0]=GEMM;launch();tick(35);oldbusy=bank_busy;release_before=releases_r;
   inject_response(2,bad);tick(10);if(error_code!=7||bank_busy!=oldbusy||releases_r!=release_before)$fatal(1,"bad identity released bank mode%0d",bad);
   @(negedge clk);allow_response=15;wait_finished();if(error_code!=7||bank_busy!=0||releases_r!=1)$fatal(1,"real match did not drain mode%0d",bad);
   scenarios=scenarios+1;
  end
  $display("DISPATCHER_SCENARIO_PASS five_identity_faults");
  reset_model();clear_program();allow_response=0;ready_mask=14;program_mem[0]=GEMM;program_mem[1]=LOAD15;launch();wait_offer(0);
  inject_response(2,1);tick(20);if(!engine_cmd_valid[0]||error_code!=7||current_pc!=1)$fatal(1,"held offer lost after fault");
  // Producer changes live descriptor epoch, but release compares acquisition epoch.
  @(negedge clk);bank_generations[1*32+:32]=bank_generations[1*32+:32]+1;ready_mask=15;allow_response=15;
  wait_finished();if(error_code!=7||accepts_r!=2||releases_r!=2||bank_busy!=0)$fatal(1,"held fault offer acquisition/drain failed");
  scenarios=scenarios+1;$display("DISPATCHER_SCENARIO_PASS held_engine_async_fault_live_epoch");
  reset_model();clear_program();allow_response=0;cfg_enable=0;program_mem[0]=GEMM;program_mem[1]=CONFIG15;launch();
  k=0;while(!cfg_valid)begin tick(1);k=k+1;if(k>100)$fatal(1,"cfg offer timeout");end
  inject_response(2,6);tick(20);if(!cfg_valid||error_code!=5)$fatal(1,"held config withdrawn after engine error");
  @(negedge clk);cfg_enable=1;wait_finished();if(cfg_accepts_r!=1||error_code!=5||bank_busy!=0)$fatal(1,"cfg error drain failed");
  scenarios=scenarios+1;$display("DISPATCHER_SCENARIO_PASS held_config_async_fault");
  reset_model();clear_program();program_mem[0]=QUANT_A;program_mem[1]=DQ;
  @(negedge clk);bank_generations[13*32+:32]=0;bank_desc_present[13]=0;
  launch();wait_finished();if(error||accepts_r!=2||releases_r!=2||bank_busy!=0)$fatal(1,"101 absent producer destination failure");
  scenarios=scenarios+1;$display("DISPATCHER_SCENARIO_PASS positional101_bank0_gen0");
  reset_model();clear_program();zero_response=15;program_mem[0]=GEMM;program_mem[1]=LOAD15;program_mem[2]=DQ;launch();wait_finished();
  if(error||accepts_r!=3||releases_r!=3)$fatal(1,"zero cycle completion failure");
  scenarios=scenarios+1;$display("DISPATCHER_SCENARIO_PASS zero_cycle_completion");
  reset_model();clear_program();allow_response=0;program_mem[0]=LOAD15;program_mem[1]=CONFIG15;launch();tick(70);
  if(cfg_valid||cfg_accepts_r!=0||current_pc!=1)$fatal(1,"busy config offered");
  @(negedge clk);allow_response=15;wait_finished();if(error||cfg_accepts_r!=1)$fatal(1,"busy cfg did not resume");
  scenarios=scenarios+1;$display("DISPATCHER_SCENARIO_PASS busy_config_stalls");
  reset_model();clear_program();for(integer n=0;n<16;n=n+1)program_mem[n]=LOAD15;launch();wait_finished();
  if(error_code!=1||accepts_r!=16||bank_busy!=0)$fatal(1,"missing END not drained");
  scenarios=scenarios+1;$display("DISPATCHER_SCENARIO_PASS missing_end");
  reset_model();clear_program();ready_mask=0;program_mem[0]=GEMM;launch();wait_offer(2);tick(10);reset_model();
  clear_program();program_mem[0]=GEMM;launch();wait_finished();if(error||accepts_r!=1||releases_r!=1)$fatal(1,"reset offered command failed");
  reset_model();clear_program();allow_response=0;program_mem[0]=GEMM;launch();tick(40);if(bank_busy==0)$fatal(1,"reset probe no live ownership");
  reset_model();clear_program();program_mem[0]=DQ;launch();wait_finished();if(error||accepts_r!=1||releases_r!=1)$fatal(1,"reset live ownership failed");
  scenarios=scenarios+2;$display("DISPATCHER_SCENARIO_PASS coordinated_reset_offer_and_live");
  reset_model();random_mode=1;
  for(integer rep=0;rep<50;rep=rep+1)begin
   clear_program();program_mem[0]=GEMM;program_mem[1]=LOAD15;program_mem[2]=STORE0;program_mem[3]=QUANT_K;program_mem[4]=FENCE;program_mem[5]=DQ;
   before_count=accepts_r;launch();wait_finished();if(error||accepts_r!=before_count+5||bank_busy!=0)$fatal(1,"random repetition%0d",rep);
  end
  scenarios=scenarios+1;$display("DISPATCHER_SCENARIO_PASS random50_monotonic_START");
  $display("DISPATCHER_PASS vectors=%0d directed=%0d random_fragments=50",VECTOR_COUNT,scenarios);$finish;
 end
 initial begin #100000000;$fatal(1,"global test timeout");end
endmodule
