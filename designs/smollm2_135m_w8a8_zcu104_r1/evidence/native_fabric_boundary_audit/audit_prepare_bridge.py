#!/usr/bin/env python3
import json,pathlib,sys
H=pathlib.Path(__file__).resolve().parent;D=H.parents[1];b=json.loads((D/'contracts/dma_transaction_bridge_rtl_binding.json').read_text());sys.path.insert(0,str(D/'scripts'));from isa_codec import encode
ports={**b['inputs'],**b['outputs']};decl='\n'.join('logic '+(f'[{w-1}:0] ' if w>1 else '')+n+';' for n,w in ports.items());inst=',\n'.join(f'.{n}({n})' for n in ports);init='\n'.join(n+"='0;" for n in b['inputs'] if n not in ['clk','resetn','mm2s_wr_commit','s2mm_rd_resp_valid','s2mm_rd_data'])
load=encode('DMA_LOAD',(2,0,0),ddr_address=0x100000,byte_count=1152,local_byte_offset=0)&((1<<112)-1)
ropestore=encode('DMA_STORE',(7,0,0),ddr_address=0x330000,byte_count=16,local_byte_offset=0)&((1<<112)-1)
ropeload=encode('DMA_LOAD',(7,0,0),ddr_address=0x310000,byte_count=128,local_byte_offset=0)&((1<<112)-1)
staticstore=encode('DMA_STORE',(7,0,0),ddr_address=0x320000,byte_count=16,local_byte_offset=4096)&((1<<112)-1)
staticonly=encode('DMA_LOAD',(7,0,0),ddr_address=0x300000,byte_count=16,local_byte_offset=4096)&((1<<112)-1)
badstatic=encode('DMA_LOAD',(7,0,0),ddr_address=0x300000,byte_count=32,local_byte_offset=6000)&((1<<112)-1)
store=encode('DMA_STORE',(2,0,0),ddr_address=0x200000,byte_count=128,local_byte_offset=0)&((1<<112)-1)
tb=r'''`timescale 1ns/1ps
module audit_dma_bridge_tb;
__DECL__
smollm2_dma_transaction_bridge dut(__INST__);
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
__INIT__
 enable_new_commands=1;bank_ready=16'hffff;bank_quiescent=16'hffff;mm2s_wr_ready=1;s2mm_rd_ready=1;embedding_ready=1;invalidate_ready=1;m_axis_mm2s_cmd_tready=1;m_axis_s2mm_cmd_tready=1;m_axis_s2mm_tready=1;s_axis_mm2s_sts_tkeep=1;s_axis_mm2s_sts_tlast=1;s_axis_s2mm_sts_tkeep=1;s_axis_s2mm_sts_tlast=1;
 boot();m_axis_mm2s_cmd_tready=0;command(0,101,112'h__LOAD__);while(!m_axis_mm2s_cmd_tvalid)ticks(1);begin logic[71:0]held;held=m_axis_mm2s_cmd_tdata;for(int k=0;k<10;k++)begin ticks(1);if(!m_axis_mm2s_cmd_tvalid||m_axis_mm2s_cmd_tdata!==held)$fatal(1,"stalled vendor command changed");end if(held[67:64]!=2||held[22:0]!=1152||held[63:32]!=32'h100000)$fatal(1,"vendor command byte span/tag");end m_axis_mm2s_cmd_tready=1;load_data();status(0,8'h82);response(0,101);if(writes!=72)$fatal(1,"load exact bytes");
 m_axis_s2mm_tready=0;command(1,202,112'h__STORE__);while(!m_axis_s2mm_tvalid)ticks(1);begin logic[144:0]held;held={m_axis_s2mm_tdata,m_axis_s2mm_tkeep,m_axis_s2mm_tlast};for(int k=0;k<20;k++)begin ticks(1);if(!m_axis_s2mm_tvalid||{m_axis_s2mm_tdata,m_axis_s2mm_tkeep,m_axis_s2mm_tlast}!==held)$fatal(1,"held S2MM beat changed");end end m_axis_s2mm_tready=1;while(stores<8)ticks(1);bank_quiescent[2]=0;status(1,8'h82);ticks(10);if(resp_valid[1]||!busy[1])$fatal(1,"quiescence barrier bypass");bank_quiescent[2]=1;response(1,202);if(reads!=8||stores!=8)$fatal(1,"read accounting");
 // Fresh wrong vendor tag is fatal and retains ownership/busy until reset.
 boot();command(0,101,112'h__LOAD__);load_data();status(0,8'h83);ticks(40);if(!faulted[0]||!busy[0]||resp_valid[0]||fault_received_tag[3:0]!=3||fault_raw_status[7:0]!=8'h83)$fatal(1,"fatal tag diagnostics or fabricated completion");
 // Malformed static range must invalidate selected static epoch, preserving RoPE.
 boot();invalidate_ready=0;bank_b7_rope_rows=2;bank_b7_rope_generation=7;bank_b7_static_generation=11;bank_b7_rope_valid=1;bank_b7_static_valid=1;
 command(0,303,112'h__BADSTATIC__,7,11,2,64,11);while(!invalidate_valid)ticks(1);
 for(int k=0;k<7;k++)begin
  if(!invalidate_valid||invalidate_bank!=7||invalidate_component!=2||invalidate_generation!=11||invalidate_transaction_id!=303||invalidate_role!=1)$fatal(1,"B7 rejected static range targets wrong component/epoch got component%0d gen%0d",invalidate_component,invalidate_generation);
  if(m_axis_mm2s_cmd_tvalid||mm2s_wr_valid||resp_valid[0])$fatal(1,"rejected range touched transport or bypassed ACK");ticks(1);
 end
 invalidate_ready=1;while(!resp_valid[0])ticks(1);if(resp_error_code[7:0]!=3||resp_bank_ids[11:0]!=7||resp_generations[95:0]!=11||resp_transaction_id[31:0]!=303||faulted[0]||writes!=0)$fatal(1,"B7 range reject completion");
 resp_ready[0]=1;ticks(1);resp_ready[0]=0;ticks(3);
 // Valid resident static component works with no RoPE/window component at all.
 bank_b7_rope_rows=0;bank_b7_rope_generation=0;bank_b7_rope_valid=0;bank_b7_static_generation=11;bank_b7_static_valid=1;m_axis_mm2s_cmd_tready=0;
 command(0,404,112'h__STATICONLY__,7,11,30,64,11);
 begin int t;t=0;while(!m_axis_mm2s_cmd_tvalid&&t<30)begin ticks(1);t++;if(resp_valid[0])$fatal(1,"valid B7 static-only LOAD rejected error%h",resp_error_code[7:0]);end if(!m_axis_mm2s_cmd_tvalid)$fatal(1,"static-only admission timeout");end
 if(m_axis_mm2s_cmd_tdata[67:64]!=7||m_axis_mm2s_cmd_tdata[22:0]!=16||writes!=0||!busy[0])$fatal(1,"static-only command or no-touch before vendor acceptance");
 m_axis_mm2s_cmd_tready=1;expected_wr_bank=7;expected_wr_gen=11;expected_wr_txn=404;expected_wr_base=256;load_data(1);status(0,8'h87);response(0,404,7,11);if(writes!=1)$fatal(1,"static-only LOAD writes");
 // Static-only STORE does not require RoPE; selected component source readiness suffices.
 bank_b7_rope_rows=0;bank_b7_rope_generation=0;bank_b7_rope_valid=0;bank_b7_static_generation=11;bank_b7_static_valid=1;expected_rd_bank=7;expected_rd_base=256;expected_store_beats=1;reads=0;stores=0;
 command(1,505,112'h__STATICSTORE__,7,11,30,64,11);while(stores<1)ticks(1);status(1,8'h87);response(1,505,7,11);if(reads!=1)$fatal(1,"static-only STORE reads");
 // Unequal B7 epochs: rope native generation1, original aggregate completion11.
 bank_b7_rope_rows=1;bank_b7_rope_generation=1;bank_b7_rope_valid=1;bank_b7_static_generation=11;bank_b7_static_valid=1;expected_wr_bank=7;expected_wr_gen=1;expected_wr_txn=606;expected_wr_base=0;writes=0;
 command(0,606,112'h__ROPELOAD__,7,11,1,64,11);load_data(8);status(0,8'h87);response(0,606,7,11);if(writes!=8)$fatal(1,"unequal rope epoch transfer");
 // First transport fault survives scheduler-abort drain; target invalidated exactly once.
 boot();m_axis_mm2s_cmd_tready=1;command(0,101,112'h__LOAD__);s_axis_mm2s_tvalid=1;s_axis_mm2s_tdata=128'h12345678;s_axis_mm2s_tkeep=16'hfffe;s_axis_mm2s_tlast=0;do @(posedge clk);while(!s_axis_mm2s_tready);@(negedge clk);s_axis_mm2s_tvalid=0;ticks(2);
 for(int k=0;k<80;k++)begin
  if(!faulted[0]||!busy[0]||resp_valid[0]||fault_reason[7:0]!=8'h60||fault_bank[3:0]!=2||fault_transaction_id[31:0]!=101||writes!=0)$fatal(1,"first partialKEEP60 fault changed during drain reason%h invalidations%0d",fault_reason[7:0],invalidations);ticks(1);
 end
 if(invalidations!=1)$fatal(1,"LOAD fatal invalidated target %0d times",invalidations);
 // Common04 for missing data/scales/selectors and individually unavailable B7 components.
 boot();command(1,808,112'h__STORE__,2,3,1,576,1,0,0,0);coverage_rejection(808,2,1);
 command(1,809,112'h__STORE__,3,4,16,576,1,1,0,0);coverage_rejection(809,3,1);
 command(1,810,112'h__STORE__,3,6,1,576,1,1,1,0);coverage_rejection(810,3,1);
 bank_b7_rope_rows=1;bank_b7_rope_generation=1;bank_b7_rope_valid=0;bank_b7_static_generation=11;bank_b7_static_valid=1;command(1,811,112'h__ROPESTORE__,7,11,1,64,11,1,1,0);coverage_rejection(811,7,11);
 bank_b7_rope_rows=0;bank_b7_rope_generation=0;bank_b7_rope_valid=0;bank_b7_static_generation=11;bank_b7_static_valid=0;command(1,812,112'h__STATICSTORE__,7,11,30,64,11,1,1,0);coverage_rejection(812,7,11);
 // Clean STORE classification: geometry/span03, opcode/reserved01, profile02, identity07.
 begin logic[111:0]p;p=112'h__STORE__;p[111:80]=1136;p[79:57]=32;command(1,901,p);coverage_rejection(901,2,1,3);end
 begin logic[111:0]p;p=112'h__STORE__;p[111:80]=1;command(1,902,p);coverage_rejection(902,2,1,3);end
 begin logic[111:0]p;p=112'h__STORE__;p[56:25]=32'hfffffff0;command(1,903,p);coverage_rejection(903,2,1,3);end
 begin logic[111:0]p;p=112'h__STORE__;p[79:57]=0;command(1,904,p);coverage_rejection(904,2,1,3);end
 begin logic[111:0]p;p=112'h__STORE__;p[3]=1;command(1,905,p);coverage_rejection(905,2,1,1);end
 command(1,906,112'h__STORE__,2,3,1,576,1,1,0,0,1);coverage_rejection(906,2,1,1);
 command(1,907,112'h__STORE__,2,31,1,576,1);coverage_rejection(907,2,1,2);
 command(1,908,112'h__STORE__,2,3,0,576,1);coverage_rejection(908,2,1,3);
 command(1,909,112'h__STORE__,8,12,1,64,1,1,1,0,-1,0,30);coverage_rejection(909,8,1,3);
 command(1,910,112'h__STORE__,13,17,1,33,1,1,0,0,-1,33,0);coverage_rejection(910,13,1,3);
 command(1,911,112'h__STORE__,2,3,1,576,1,1,0,0,-1,0,0,3);coverage_rejection(911,2,1,7);
 bank_b7_rope_rows=1;bank_b7_rope_generation=1;bank_b7_rope_valid=1;bank_b7_static_generation=10;bank_b7_static_valid=1;command(1,912,112'h__STATICSTORE__,7,11,30,64,11,1,1);coverage_rejection(912,7,11,7);
 command(1,913,112'h__STORE__,2,4,16,576,1,1,1);coverage_rejection(913,2,1,2);
 command(1,914,112'h__STORE__,2,3,1,576,0);coverage_rejection(914,2,0,7);
 $display("AUDIT_DMA_BRIDGE_PASS writes=%0d reads=%0d stores=%0d cycles=%0d",writes,reads,stores,cycles);$finish;
end
endmodule
'''
for a,z in {'__DECL__':decl,'__INST__':inst,'__INIT__':init,'__LOAD__':f'{load:028x}','__STORE__':f'{store:028x}','__BADSTATIC__':f'{badstatic:028x}','__STATICONLY__':f'{staticonly:028x}','__STATICSTORE__':f'{staticstore:028x}','__ROPELOAD__':f'{ropeload:028x}','__ROPESTORE__':f'{ropestore:028x}'}.items():tb=tb.replace(a,z)
(H/'audit_dma_bridge_tb.sv').write_text(tb);print(H/'audit_dma_bridge_tb.sv')
