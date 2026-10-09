#!/usr/bin/env python3
"""Independent control integration fixture/TB generator; no tensor numerical claims."""
import hashlib,json,pathlib,sys
HERE=pathlib.Path(__file__).resolve().parent
D=HERE.parents[1]
spec=json.loads((D/'isa_spec.json').read_text())
b=json.loads((D/'contracts/infrastructure_rtl_port_binding.json').read_text())
fields={};dp=[];bc=[]
def add(group,key,target):
 for name,width in group.get(key,{}).items():
  if name in fields: assert fields[name]==width
  fields[name]=width;target.append(name)
add(b['dispatcher_control'],'inputs',dp);add(b['dispatcher_control'],'outputs',dp)
for name,width in b['state_outputs'].items(): fields[name]=width;dp.append(name);bc.append(name)
for group in ['acquire','release','config']:
 add(b[group],'inputs',dp);add(b[group],'outputs',dp)
 add(b[group],'inputs',bc);add(b[group],'outputs',bc)
for group in ['engine_cmd','engine_resp']:
 add(b[group],'inputs',dp);add(b[group],'outputs',dp)
for group in ['producer','invalidate','coverage','embedding']:
 add(b[group],'inputs',bc);add(b[group],'outputs',bc)
bc=['clk','resetn']+bc
byname={x['opcode']:x for x in spec['opcodes']}
def enc(op,banks=(0,0,0),**kw):
 item=byname[op];v=item['encoding']<<124
 for p,bank in enumerate(banks):v|=bank<<(120-4*p)
 for f,n in kw.items(): hi,lo=spec['instruction_record']['payload_formats'][item['payload_format']][f];assert n<1<<(hi-lo+1);v|=n<<lo
 return v
def cfg(bank,profile,cols=576):return enc('BANK_CONFIG',(bank,0,0),profile=profile,rows=1,cols=cols,generation=1)
gemm=enc('GEMM_INT8',(13,3,1),m_count=1,k=576,n_tile=16,n_total=576)
dma15=enc('DMA_LOAD',(15,0,0),byte_count=16,ddr_address=0x1000)
dma13=enc('DMA_LOAD',(13,0,0),byte_count=16,ddr_address=0x2000)
quant=enc('QUANTIZE',(2,0,13),mode=0,m_count=1,k=576)
dq=enc('DEQUANTIZE',(3,0,0),m_count=1,k=576)
programs={
 'concurrent':[cfg(13,21),cfg(3,4),cfg(1,2),cfg(15,4),gemm,dma15,dma13,0],
 'fence':[dma15,enc('FENCE'),dma13,0],
 'quant':[quant,0], 'dq':[dq,0], 'bad':[gemm,0], 'retained':[gemm,dma15,0],
 'unsupported':[(4<<124)|(0<<120)|(3<<116)|(2<<112)|1,0]}
programs['b7']=[enc('BANK_CONFIG',(7,0,0),profile=11,rows=30,cols=64,component=2,generation=1),enc('BANK_CONFIG',(7,0,0),profile=11,rows=1,cols=64,component=1,generation=2),enc('DMA_LOAD',(7,0,0),byte_count=16,ddr_address=0x1000),0]
programs['orientation0']=[enc('DMA_LOAD',(i,0,0),byte_count=16,ddr_address=0x1000) for i in range(15)]+[0]
programs['orientation1']=[enc('DMA_LOAD',(15,0,0),byte_count=16,ddr_address=0x1000),0]
for name,prog in programs.items():(HERE/f'audit_{name}.hex').write_text(''.join(f'{x:032x}\n' for x in prog+[0]*(16-len(prog))))
ports=lambda names: ',\n'.join(' .'+x+'('+x+')' for x in names)
decls='\n'.join(f'logic '+(f'[{width-1}:0] ' if width>1 else '')+name+';' for name,width in fields.items())
metadata_inputs=[]
for group in ['producer','invalidate','coverage','embedding']:metadata_inputs += list(b[group]['inputs'])
resetmeta='\n'.join(f' {x}=0;' for x in metadata_inputs)
tb=r'''`timescale 1ns/1ps
module audit_infrastructure_tb;
__DECLS__
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
__INST__
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
__RESET_META__
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
'''
inst='smollm2_isa_dispatcher dispatch(\n'+ports(dp)+'\n);\nsmollm2_bank_controller banks(\n'+ports(bc)+'\n);'
tb=tb.replace('__DECLS__',decls).replace('__INST__',inst).replace('__RESET_META__',resetmeta)
(HERE/'audit_infrastructure_tb.sv').write_text(tb)
print(HERE/'audit_infrastructure_tb.sv')
