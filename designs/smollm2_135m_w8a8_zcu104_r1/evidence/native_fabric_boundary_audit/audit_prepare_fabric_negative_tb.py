#!/usr/bin/env python3
"""Prepare actual-fabric protocol TB, exterior DDR/AXIS only. No DUT data preload."""
import json,pathlib
H=pathlib.Path(__file__).resolve().parent;D=H.parents[1];B=json.loads((D/'contracts/execution_fabric_rtl_binding.json').read_text());P=H/'fabric_negative_vectors'
ports={**B['inputs'],**B['outputs']};decl='\n'.join('logic '+(f'[{w-1}:0] ' if w>1 else '')+n+';' for n,w in ports.items());init='\n'.join(n+"=0;" for n in B['inputs'] if n not in ['clk','resetn'])
tb=r'''`timescale 1ns/1ps
module audit_fabric_negative_tb;
__DECL__
smollm2_execution_fabric dut(.*);
logic[127:0]source_words[0:71];logic[127:0]expected_words[0:7];logic[127:0]program_records[0:15];int cycles=0,cmd_checks=0,beat_checks=0,completed_fragments=0;bit prohibit_store=0;
always #2.5 clk=~clk;
always @(posedge clk)begin
 cycles++;if(cycles>500000)$fatal(1,"watchdog");
 if(resetn&&prohibit_store&&m_axis_s2mm_cmd_tvalid)$fatal(1,"partial coverage issued STORE vendorcommand");
end
task automatic ticks(input int n);repeat(n)@(negedge clk);endtask
task automatic boot;
 resetn=0;start=0;program_wr_valid=0;s_axis_mm2s_tvalid=0;s_axis_mm2s_sts_tvalid=0;s_axis_s2mm_sts_tvalid=0;m_axis_mm2s_cmd_tready=0;m_axis_s2mm_cmd_tready=0;m_axis_s2mm_tready=0;ticks(5);resetn=1;
 begin int t;t=0;while((!initialized||!start_ready)&&t<40000)begin ticks(1);t++;end if(!initialized||!start_ready)$fatal(1,"physicalcoverage initialization timeout");end
 if(error||busy||dma_faulted)$fatal(1,"reset status not clean");
endtask
task automatic preload(input string name);
 for(int k=0;k<16;k++)program_records[k]=0;$readmemh({"__PATH__/",name,".hex"},program_records);
 for(int k=0;k<16;k++)begin program_wr_valid=1;program_wr_address=4'(k);program_wr_data=program_records[k];program_wr_strb=16'hffff;do @(posedge clk);while(!program_wr_ready);@(negedge clk);program_wr_valid=0;end
endtask
task automatic launch;
 if(!start_ready)$fatal(1,"START not ready");start=1;program_wr_valid=1;program_wr_address=0;program_wr_data='1;program_wr_strb=16'hffff;
 #0.1;if(program_wr_ready)$fatal(1,"START lost PSwrite priority");ticks(1);start=0;program_wr_valid=0;
endtask
task automatic status(input bit store,input logic[7:0]code);
 if(!store)begin s_axis_mm2s_sts_tdata=code;s_axis_mm2s_sts_tvalid=1;do @(posedge clk);while(!s_axis_mm2s_sts_tready);@(negedge clk);s_axis_mm2s_sts_tvalid=0;end
 else begin s_axis_s2mm_sts_tdata=code;s_axis_s2mm_sts_tvalid=1;do @(posedge clk);while(!s_axis_s2mm_sts_tready);@(negedge clk);s_axis_s2mm_sts_tvalid=0;end
endtask
task automatic accept_load(input int offset,input int bytes,output logic[3:0]tag);
 m_axis_mm2s_cmd_tready=1;do @(posedge clk);while(!m_axis_mm2s_cmd_tvalid);if(m_axis_mm2s_cmd_tdata[63:32]!=32'h100000+32'(offset)||m_axis_mm2s_cmd_tdata[22:0]!=23'(bytes)||m_axis_mm2s_cmd_tdata[67:64]!=2)$fatal(1,"DMA_LOAD vendor span/tag mismatch");tag=m_axis_mm2s_cmd_tdata[67:64];cmd_checks++;@(negedge clk);m_axis_mm2s_cmd_tready=0;
endtask
task automatic load(input int offset,input int bytes);
 logic[3:0]tag;accept_load(offset,bytes,tag);
 for(int k=0;k<bytes/16;k++)begin s_axis_mm2s_tdata=source_words[offset/16+k];s_axis_mm2s_tkeep=16'hffff;s_axis_mm2s_tlast=(k==bytes/16-1);s_axis_mm2s_tvalid=1;do @(posedge clk);while(!s_axis_mm2s_tready);beat_checks++;@(negedge clk);s_axis_mm2s_tvalid=0;end
 status(0,8'h80|{4'd0,tag});
endtask
task automatic store;
 logic[3:0]tag;m_axis_s2mm_cmd_tready=1;do @(posedge clk);while(!m_axis_s2mm_cmd_tvalid);if(m_axis_s2mm_cmd_tdata[63:32]!=32'h200000||m_axis_s2mm_cmd_tdata[22:0]!=128||m_axis_s2mm_cmd_tdata[67:64]!=2)$fatal(1,"STORE vendor span/tag mismatch");tag=m_axis_s2mm_cmd_tdata[67:64];cmd_checks++;@(negedge clk);m_axis_s2mm_cmd_tready=0;m_axis_s2mm_tready=1;
 for(int k=0;k<8;k++)begin do @(posedge clk);while(!m_axis_s2mm_tvalid);if(m_axis_s2mm_tdata!==expected_words[k]||m_axis_s2mm_tkeep!=16'hffff||m_axis_s2mm_tlast!=(k==7))$fatal(1,"physicalmemory STORE mismatch lane%0d",k);beat_checks++;@(negedge clk);end
 m_axis_s2mm_tready=0;status(1,8'h80|{4'd0,tag});
endtask
task automatic finish(input logic[7:0]expected_error);
 begin int t;t=0;while(busy&&t<1000)begin ticks(1);t++;end if(busy)$fatal(1,"completion drain timeout");end
 if(expected_error==0)begin if(!done||error)$fatal(1,"fragment didnotEND cleanly");end else if(!error||error_code!=expected_error)$fatal(1,"wrong clean reject code%h",error_code);
 completed_fragments++;ticks(5);
endtask
initial begin
 clk=0;resetn=0;
__INIT__
 s_axis_mm2s_sts_tkeep=1;s_axis_mm2s_sts_tlast=1;s_axis_s2mm_sts_tkeep=1;s_axis_s2mm_sts_tlast=1;
 $readmemh("__PATH__/source.hex",source_words);$readmemh("__PATH__/expected_store.hex",expected_words);
 boot();preload("partial_duplicate");prohibit_store=1;launch();load(0,1136);load(0,16);finish(8'h04);prohibit_store=0;
 // No config/reset: persistent exactcoverage, descriptors, physicalRAM acrossSTART.
 preload("fill_tail_next_start");launch();load(1136,16);store();finish(0);
 // Fresh fatal partialKEEP case: no accepted malformed native write, sticky diagnostic/ownership.
 boot();preload("fault_load");launch();begin logic[3:0]tag;accept_load(0,1152,tag);end
 s_axis_mm2s_tdata='1;s_axis_mm2s_tkeep=16'hfffe;s_axis_mm2s_tlast=0;s_axis_mm2s_tvalid=1;do @(posedge clk);while(!s_axis_mm2s_tready);@(negedge clk);s_axis_mm2s_tvalid=0;ticks(4);
 for(int k=0;k<80;k++)begin if(!dma_faulted[0]||dma_fault_reason[7:0]!=8'h60||dma_fault_bank[3:0]!=2||!busy||!error||error_code!=8'h06||start_ready||program_wr_ready)$fatal(1,"stickyfatal lost identity/halt/ownership reason%h",dma_fault_reason[7:0]);ticks(1);end
 // Bad external status while vendor command is offered but stalled: retain offer through fatal drain.
 boot();preload("fault_load");launch();m_axis_mm2s_cmd_tready=0;while(!m_axis_mm2s_cmd_tvalid)ticks(1);
 begin logic[71:0]held;held=m_axis_mm2s_cmd_tdata;ticks(3);status(0,8'h83);
  for(int k=0;k<40;k++)begin if(!m_axis_mm2s_cmd_tvalid||m_axis_mm2s_cmd_tdata!==held)$fatal(1,"offered vendorcommand withdrawn onlatefault");ticks(1);end
 end
 if(!dma_faulted[0]||!busy||start_ready)$fatal(1,"held vendorcommand badstatus notstickyfatal");
 m_axis_mm2s_cmd_tready=1;ticks(1);m_axis_mm2s_cmd_tready=0;cmd_checks++;ticks(10);if(!busy||start_ready)$fatal(1,"fatal command acceptance fabricatedretirement");
 // Coordinated reset is sole recovery; whole physical pool reinitializes beforeSTART.
 boot();preload("full_load");launch();load(0,1152);finish(0);
 preload("fault_store_next_start");launch();m_axis_s2mm_cmd_tready=1;do @(posedge clk);while(!m_axis_s2mm_cmd_tvalid);@(negedge clk);m_axis_s2mm_cmd_tready=0;cmd_checks++;m_axis_s2mm_tready=0;while(!m_axis_s2mm_tvalid)ticks(1);
 begin logic[144:0]held;held={m_axis_s2mm_tdata,m_axis_s2mm_tkeep,m_axis_s2mm_tlast};if(m_axis_s2mm_tdata!==expected_words[0])$fatal(1,"held realbank STORE payload");status(1,8'h83);for(int k=0;k<40;k++)begin if(!m_axis_s2mm_tvalid||{m_axis_s2mm_tdata,m_axis_s2mm_tkeep,m_axis_s2mm_tlast}!==held)$fatal(1,"STORE offered beat withdrawn onfault");ticks(1);end end
 m_axis_s2mm_tready=1;ticks(1);m_axis_s2mm_tready=0;ticks(20);if(!dma_faulted[1]||!busy||!error||error_code!=6||start_ready)$fatal(1,"STORE fatal fabricatedquiescent completion");
 if(cmd_checks!=8||completed_fragments!=3||beat_checks<153)$fatal(1,"vacuous protocol coverage commands%0d fragments%0d beats%0d",cmd_checks,completed_fragments,beat_checks);
 $display("AUDIT_FABRIC_NEGATIVE_PASS commands=%0d fragments=%0d beats=%0d cycles=%0d",cmd_checks,completed_fragments,beat_checks,cycles);$finish;
end
endmodule
'''
for old,new in {'__DECL__':decl,'__INIT__':init,'__PATH__':str(P)}.items():tb=tb.replace(old,new)
(H/'audit_fabric_negative_tb.sv').write_text(tb);print(H/'audit_fabric_negative_tb.sv')
