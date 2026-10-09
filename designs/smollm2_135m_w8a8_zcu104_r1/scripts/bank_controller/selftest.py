import pathlib,json,subprocess,hashlib
B=pathlib.Path(__file__).resolve().parents[2]; E=B/'evidence/infrastructure_wave/bank_controller';E.mkdir(parents=True,exist_ok=True)
j=json.loads((B/'contracts/infrastructure_rtl_port_binding.json').read_text());ports={'clk':1,'resetn':1};inputs=['clk','resetn']
ports.update(j['state_outputs'])
for sec in ['acquire','release','config','producer','invalidate','coverage','embedding']:
 for d in ['inputs','outputs']:
  ports.update(j[sec][d]);
  if d=='inputs': inputs+=list(j[sec][d])
s='`timescale 1ns/1ps\nmodule tb;\n'+''.join('logic '+('' if w==1 else f'[{w-1}:0] ')+n+';\n' for n,w in ports.items())
s+='smollm2_bank_controller dut(.*);\ninitial clk=0;always #2.5 clk=~clk;\n'
s+='''
task tick; @(posedge clk); #1; @(negedge clk); endtask
integer assertions=0;
task check(input logic ok,input string msg);assertions=assertions+1;if(!ok)$fatal(1,"%s",msg);endtask
task cfg(input logic[3:0] b,input logic[4:0] p,input logic[10:0] rows,
 input logic[15:0] cols,input logic[1:0] comp,input logic[31:0] gen,input logic[7:0] err);
 @(negedge clk);cfg_bank=b;cfg_profile=p;cfg_rows=rows;cfg_cols=cols;cfg_component=comp;cfg_generation=gen;
 cfg_valid=1;#1;check(cfg_ready,"cfg ready");tick();cfg_valid=0;
 check(cfg_resp_valid&&cfg_resp_error_code==err,"cfg response"); tick();
endtask
task acq(input logic[3:0] b,input logic[4:0] role,input logic[31:0] gen);
 @(negedge clk);acquire_used_bank_mask=1;acquire_bank_ids={8'd0,b};acquire_roles={10'd0,role};
 acquire_generations={64'd0,gen};acquire_valid=1;#1;$display("acq b%0d gen%0d ready%0d err%0d busy%h meta%h",b,gen,acquire_ready,acquire_error_code,bank_busy,dut.meta_mask_w);check(acquire_ready&&acquire_error_code==0,"acq eligibility");
 tick();acquire_valid=0;check(bank_busy[b],"acquired");
endtask
task rel(input logic[3:0] b,input logic[4:0] role,input logic[31:0] gen,input logic[7:0] err);
 @(negedge clk);release_used_bank_mask=1;release_bank_ids={8'd0,b};release_roles={10'd0,role};
 release_generations={64'd0,gen};release_valid=1;#1;
 check(release_ready&&release_error_code==err,"release eligibility");tick();release_valid=0;
endtask
task cov(input logic[3:0] b,input logic[1:0] comp,input logic[31:0] gen,input logic[4:0] role,input logic[7:0] err);
 @(negedge clk);coverage_bank=b;coverage_component=comp;coverage_generation=gen;coverage_role=role;
 coverage_valid=1;#1;check(coverage_ready&&coverage_error_code==err,"coverage eligibility");tick();coverage_valid=0;
endtask
initial begin
'''+''.join(n+"=0;\n" for n in inputs if n!='clk')+'''
cfg_resp_ready=1;acquire_transaction_id=9;release_transaction_id=9;
producer_transaction_id=9;coverage_transaction_id=9;invalidate_transaction_id=9;embedding_transaction_id=9;
coverage_data_complete=1;coverage_scale_complete=1;
tick();resetn=1;tick();check(bank_busy==0&&bank_desc_present==0,"reset");
// Config held response does not own the bank, and busy config cannot mutate.
cfg_resp_ready=0;cfg(0,1,1,576,0,1,0);
check(cfg_resp_valid&&bank_busy==0,"held cfg no lock");acq(0,24,1);
check(cfg_resp_valid&&cfg_resp_error_code==0,"held response stable");
cfg_resp_ready=1;tick();cfg(0,1,2,576,0,2,7);
check(bank_rows[0+:11]==1&&bank_generations[0+:32]==1,"busy cfg no touch");
rel(0,24,2,7);check(bank_busy[0],"wrong release retained");rel(0,24,1,0);
rel(0,24,1,7);check(!bank_busy[0],"duplicate release");
// Atomic aliases and stale generations never acquire a prefix.
acquire_used_bank_mask=3;acquire_bank_ids=12'h110;acquire_roles={5'd0,5'd3,5'd3};acquire_generations={32'd0,32'd1,32'd1};
#1;check(!acquire_ready&&acquire_error_code==7,"stale mixed tuple");
acquire_bank_ids=0;acquire_generations={32'd0,32'd1,32'd1};#1;check(!acquire_ready&&acquire_error_code==7,"alias tuple");
check(bank_busy==0,"no partial lock");
// Destination absent/gen0, producer begin1, release must use original0.
acq(13,23,0);producer_bank=13;producer_role=23;producer_accepted_generation=0;
producer_generation=1;producer_profile=21;producer_rows=17;producer_cols=576;producer_valid=1;
#1;check(producer_ready&&producer_error_code==0,"producer gen0 begin");tick();producer_valid=0;
check(bank_generations[13*32+:32]==1,"live epoch new");cov(13,0,1,23,0);
check(bank_data_valid[13]&&bank_scale_valid[13],"coverage complete");cov(13,0,1,23,0);
check(bank_data_valid[13],"duplicate monotonic");cov(13,0,0,23,7);
producer_valid=1;#1;check(producer_error_code==7,"duplicate producer no touch");tick();producer_valid=0;
check(bank_data_valid[13],"duplicate producer coverage preserved");
invalidate_bank=13;invalidate_role=23;invalidate_generation=1;invalidate_valid=1;
#1;check(invalidate_error_code==0,"invalidate epoch");tick();invalidate_valid=0;
cov(13,0,1,23,7);check(!bank_data_valid[13]&&!bank_scale_valid[13],"sticky invalidation");
rel(13,23,1,7);check(bank_busy[13],"live gen release rejected");rel(13,23,0,0);
check(!bank_busy[13],"original gen releases");cfg(13,21,17,576,0,2,0);
acq(13,23,2);cov(13,0,2,23,0);check(bank_data_valid[13],"new epoch restores");rel(13,23,2,0);
// B7 independent component epochs and preservation of existing rope descriptor.
cfg(7,11,2,64,1,10,0);acq(7,1,10);cov(7,1,10,1,0);rel(7,1,10,0);
cfg(7,11,30,64,2,4,0);check(bank_rows[77+:11]==2&&bank_generations[224+:32]==10&&bank_b7_rope_valid,"static preserves rope");
acq(7,1,10);cov(7,2,4,1,0);check(bank_b7_static_valid&&bank_b7_rope_valid,"B7 both valid");invalidate_bank=7;invalidate_role=1;invalidate_component=2;invalidate_generation=4;invalidate_valid=1;
#1;check(invalidate_error_code==0,"B7 static invalidate component epoch");tick();invalidate_valid=0;
check(bank_b7_rope_valid&&!bank_b7_static_valid,"B7 static failure preserves rope");cov(7,2,4,1,7);
rel(7,1,10,0);cfg(7,11,30,64,2,5,0);acq(7,1,10);cov(7,2,5,1,0);rel(7,1,10,0);
cfg(7,11,3,64,1,11,0);check(bank_b7_static_valid&&!bank_b7_rope_valid,"rope preserves static");
acq(7,1,11);cov(7,1,11,1,0);
invalidate_component=1;invalidate_generation=11;invalidate_valid=1;
#1;check(invalidate_error_code==0,"B7 rope invalidate");tick();invalidate_valid=0;
check(!bank_b7_rope_valid&&bank_b7_static_valid,"B7 rope failure preserves static");cov(7,1,11,1,7);
invalidate_component=0;cov(7,2,10,1,7);check(bank_b7_static_valid,"component stale no touch");rel(7,1,11,0);
cfg(7,11,3,64,0,10,7);check(bank_generations[224+:32]==11,"B7 full cfg monotonic");
// Embedding metadata is authenticated and separately tracked per row.
cfg(3,6,2,576,0,1,0);acq(3,1,1);cov(3,0,1,1,0);
check(bank_embedding_lane_valid==0,"coverage does not invent lanes");
embedding_role=1;embedding_generation=1;embedding_row=1;embedding_lane=3;embedding_valid=1;
#1;check(embedding_ready&&embedding_error_code==0,"embedding");tick();embedding_valid=0;
check(bank_embedding_lane_valid==2&&bank_embedding_lanes[2+:2]==3,"embedding row lane");
embedding_row=2;embedding_valid=1;#1;check(embedding_error_code==7,"embedding row bound");tick();embedding_valid=0;
rel(3,1,1,0);
// Disjoint release/acquire same edge. Used-mask hole ignores unused bank0.
acq(0,24,1);acquire_used_bank_mask=3'b101;acquire_bank_ids={4'd15,4'd0,4'd14};
acquire_roles={5'd4,5'd0,5'd3};acquire_generations=0;acquire_valid=1;
release_bank_ids=0;release_roles=24;release_generations=1;release_used_bank_mask=1;release_valid=1;
#1;check(acquire_ready&&release_ready&&release_error_code==0,"disjoint ready");tick();acquire_valid=0;release_valid=0;
check(!bank_busy[0]&&bank_busy[14]&&bank_busy[15],"disjoint commit");
// Three-bank tuple acquisition and wrong-transaction atomic release.
@(negedge clk);acquire_used_bank_mask=7;acquire_bank_ids={4'd4,4'd2,4'd1};
acquire_roles={5'd5,5'd4,5'd3};acquire_generations=0;acquire_valid=1;
#1;check(acquire_ready,"three bank eligible");tick();acquire_valid=0;
check(bank_busy[1]&&bank_busy[2]&&bank_busy[4],"three bank acquired");
release_used_bank_mask=7;release_bank_ids=acquire_bank_ids;release_roles=acquire_roles;
release_generations=0;release_transaction_id=10;release_valid=1;
#1;check(release_error_code==7,"wrong txn release");tick();
check(bank_busy[1]&&bank_busy[2]&&bank_busy[4],"wrong txn no release prefix");
release_transaction_id=9;#1;check(release_error_code==0,"matched tuple");tick();release_valid=0;
check(!bank_busy[1]&&!bank_busy[2]&&!bank_busy[4],"atomic tuple released");
// Invalidation wins against same-cycle coverage and release, then remains sticky.
acq(13,23,2);coverage_bank=13;coverage_component=0;coverage_generation=2;coverage_role=23;coverage_valid=1;
invalidate_bank=13;invalidate_role=23;invalidate_generation=2;invalidate_component=0;invalidate_valid=1;
release_used_bank_mask=1;release_bank_ids=13;release_roles=23;release_generations=2;release_valid=1;
#1;check(!coverage_ready&&!release_ready&&invalidate_ready,"metadata priority");tick();
coverage_valid=0;invalidate_valid=0;release_valid=0;
check(bank_busy[13]&&!bank_data_valid[13]&&!bank_scale_valid[13],"invalidate dominates");
cov(13,0,2,23,7);rel(13,23,2,0);
acq(13,23,2);producer_bank=13;producer_role=23;producer_accepted_generation=2;
producer_generation=3;producer_profile=21;producer_rows=17;producer_cols=576;producer_valid=1;
#1;check(producer_error_code==0,"new producer clears invalid epoch");tick();producer_valid=0;
cov(13,0,3,23,0);check(bank_data_valid[13],"producer epoch recovery");rel(13,23,2,0);
// Atomic config takes precedence over acquire of the same free bank.
@(negedge clk);cfg_bank=2;cfg_profile=3;cfg_rows=1;cfg_cols=576;cfg_component=0;cfg_generation=1;cfg_valid=1;
acquire_used_bank_mask=1;acquire_bank_ids=2;acquire_roles=3;acquire_generations=0;acquire_valid=1;
#1;check(!acquire_ready&&cfg_ready,"cfg acquire serialization");tick();cfg_valid=0;
check(!bank_busy[2]&&bank_generations[64+:32]==1,"cfg exclusive commit");
acquire_generations=1;#1;check(acquire_ready,"acquire after cfg");tick();acquire_valid=0;
check(bank_busy[2],"postcfg lock");
// Terminal generation cannot wrap via producer or be reused via config.
rel(2,3,1,0);cfg(2,3,1,576,0,32'hffffffff,0);acq(2,3,32'hffffffff);
producer_bank=2;producer_role=3;producer_accepted_generation=32'hffffffff;producer_generation=0;
producer_profile=3;producer_rows=1;producer_cols=576;producer_valid=1;
#1;check(producer_error_code==7,"producer wrap rejected");tick();producer_valid=0;
check(bank_generations[64+:32]==32'hffffffff,"nonwrap no mutation");rel(2,3,32'hffffffff,0);
cfg(2,3,1,576,0,32'hffffffff,7);
// Coordinated reset clears every public state including held response.
resetn=0;tick();check(bank_busy==0&&bank_desc_present==0&&bank_embedding_lane_valid==0&&bank_generations==0,"activity reset");
$display("ASSERTIONS %0d",assertions);$display("PASS_BANK_CONTROLLER_SELFTEST");$finish;
end
initial begin #50000;$fatal(1,"timeout");end
endmodule
'''
(E/'selftest_tb.sv').write_text(s)
cmd=['iverilog','-g2012','-s','tb','-o',str(E/'sim.vvp'),str(E/'selftest_tb.sv'),str(B/'rtl/smollm2_bank_controller.sv'),str(B/'rtl/bank_ownership_table.sv')]
r=subprocess.run(cmd,text=True,capture_output=True);(E/'compile.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
r=subprocess.run(['vvp',str(E/'sim.vvp')],text=True,capture_output=True);(E/'simulation.log').write_text(r.stdout+r.stderr);print(r.stdout+r.stderr);assert r.returncode==0
(E/'selftest_report.json').write_text(json.dumps({'status':'PASS','source_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [B/'rtl/smollm2_bank_controller.sv',B/'rtl/bank_ownership_table.sv']},'coverage':['busy and held config','tuple aliases/stale generation/no prefix','original acquisition vs live producer generation','gen0 absent producer destination','duplicate producer/coverage/release','sticky invalidate late coverage','B7 percomponent epoch and preservation','embedding selected lane and row bounds','disjoint acquire/release and used mask hole','coordinated active reset']},indent=2)+'\n')
