from pathlib import Path
import sys,subprocess,json,hashlib
r=Path('/home/shmin/llm2rtl');d=r/'designs/attention_w4a4kv4_bf16scale_isa_r1';e=d/'evidence/control_final002';o=Path('/tmp/control_latefault_independent');o.mkdir(exist_ok=False)
m=json.loads((e/'manifest.json').read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,h in m['sources'].items():assert sha(e/'source_snapshot'/name)==h,name
s=(e/'source_snapshot/designs/attention_w4a4kv4_bf16scale_isa_r1/tb/tb_attention_control.sv').read_text();a=s.index('  initial begin\n    aresetn=0;');b=s.index('  initial begin #1000000;',a)
s=s[:a]+'''  task automatic prepare_dma;
    reset();program_mem[0]=instruction(1,18,0,0,18,64'h10000000);start();wait_mm2s();
    m_ctrl_mm2s_cmd_ready=1;tick();@(negedge aclk);m_ctrl_mm2s_cmd_ready=0;
    for(int w=0;w<attention_tensor_config_pkg::capacity_words(5'd18);w++)begin
      mm2s_write_valid=1;mm2s_write_bank=18;mm2s_write_addr=32'(w);mm2s_write_data=128'(w);
      #0.1;if(!mm2s_write_ready)$fatal(1,"repro lacked legal accepted DMA payload phase");tick();@(negedge aclk);
    end
    mm2s_write_valid=0;
    if(bank_error||u_banks.router_error_w||cmd_dispatcher_error||!bank_busy[18]||bank_valid[18])$fatal(1,"repro not clean owned phase");
  endtask
  initial begin
    for(int mode=0;mode<3;mode++)begin
      prepare_dma();
      s_ctrl_mm2s_sts_valid=1;s_ctrl_mm2s_sts_bank=18;
      if(mode==0)begin mm2s_write_valid=1;mm2s_write_bank=17;mm2s_write_addr=0;end
      #0.1;if(mode==0&&(mm2s_write_ready||u_banks.mem_ena[17]))$fatal(1,"repro unauthorized request actually touched memory");
      tick();
      $display("TRACE mode%0d after_completion state%0d busy%h valid%h bankerror%0b routererror%0b release%h ack%h",mode,u_controller.state_r,bank_busy,bank_valid,bank_error,u_banks.router_error_w,bank_release_valid,bank_release_accepted);
      @(negedge aclk);s_ctrl_mm2s_sts_valid=0;mm2s_write_valid=0;
      if(mode!=0)begin
        mm2s_write_valid=1;mm2s_write_bank=mode==1?5'd18:5'd17;
        mm2s_write_addr=mode==1?attention_tensor_config_pkg::capacity_words(5'd18):32'd0;
        #0.1;if(mm2s_write_ready||u_banks.mem_ena[mm2s_write_bank])$fatal(1,"repro bad request touched memory");
      end
      tick();
      $display("TRACE mode%0d after_release state%0d busy%h valid%h bankerror%0b routererror%0b",mode,u_controller.state_r,bank_busy,bank_valid,bank_error,u_banks.router_error_w);
      if(bank_busy!=0||!bank_valid[18])$fatal(1,"expected historical release/commit race absent");
      @(negedge aclk);mm2s_write_valid=0;repeat(3)tick();
      $display("TRACE mode%0d terminal_error%0b code%0d busy%h valid%h",mode,cmd_dispatcher_error,cmd_dispatcher_error_code,bank_busy,bank_valid);
      if(!cmd_dispatcher_error||bank_busy!=0||!bank_valid[18])$fatal(1,"historical race terminal trace mismatch");
    end
    $display("CONTROL_REVIEW_REPRO_CONFIRMED");$finish;
  end
'''+s[b:];tb=o/'tb_attention_control.sv';tb.write_text(s)
base=Path('designs/attention_w4a4kv4_bf16scale_isa_r1/rtl');paths=[base/n for n in ['attention_tensor_pkg.sv','attention_tensor_config_pkg.sv','attention_descriptor_rom.sv','attention_tensor_controller.sv']]+[Path('ip/infrastructure/bank_ownership_table/rtl/bank_ownership_table.sv'),Path('ip/infrastructure/bank_port_router/rtl/bank_port_router.sv'),Path('ip/infrastructure/datamover_engine/rtl/bram_bank.sv'),base/'attention_tensor_bank_subsystem.sv'];sources=[e/'source_snapshot'/p for p in paths]
sys.path.insert(0,str(r/'designs/attention_int4_noscale_zcu104_r1/scripts'));from xsim_runtime import VIVADO,snapshot_run
for tool,args,log in [('xvlog',['--sv',*sources,tb],'compile.log'),('xelab',['tb_attention_control','-L','xpm','-s','latefault_repro','-timescale','1ns/1ps'],'elaborate.log')]:
 with(o/log).open('w')as f:p=subprocess.run([str(VIVADO/tool),*map(str,args)],cwd=o,stdout=f,stderr=subprocess.STDOUT,timeout=120)
 (o/(log+'.exit')).write_text(str(p.returncode));assert p.returncode==0,log
snapshot_run(o/'xsim.dir/latefault_repro/xsimk',o,o/'simulation.log','CONTROL_REVIEW_REPRO_CONFIRMED')
(o/'manifest.json').write_text(json.dumps({'scope':'historical negative reproduction only; no promotion','control_final002_manifest_sha256':sha(e/'manifest.json'),'source_sha256':{str(p):sha(p)for p in sources+[tb]},'temporary_tb_sha256':sha(tb)},indent=2)+'\n')
print((o/'simulation.log.stdout').read_text())
