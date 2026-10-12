#!/usr/bin/env python3
"""Control-only verification: mock executor transactions and actual XPM bank pool."""
import argparse,hashlib,json,shutil,subprocess,sys
from pathlib import Path
BASE=Path(__file__).resolve().parents[1];ROOT=BASE.parents[1]
sys.path.insert(0,str(ROOT/'designs/attention_int4_noscale_zcu104_r1/scripts'))
from xsim_runtime import snapshot_run,VIVADO

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(args,cwd,log):
 with log.open('w') as f: p=subprocess.run([str(x) for x in args],cwd=cwd,stdout=f,stderr=subprocess.STDOUT,timeout=600)
 log.with_suffix(log.suffix+'.exit').write_text(str(p.returncode)+'\n')
 if p.returncode:raise RuntimeError('command failed: '+str(log))
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--out',required=True,type=Path);ap.add_argument('--mode',choices=['sim','lint','synth','all'],default='all');ap.add_argument('--late-fault-case',type=int,choices=[-1,0,1,2,3],default=-1);args=ap.parse_args()
 out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 rtl=BASE/'rtl';ip=ROOT/'ip/infrastructure'
 sources=[rtl/'attention_tensor_pkg.sv',rtl/'attention_tensor_config_pkg.sv',rtl/'attention_descriptor_rom.sv',rtl/'attention_tensor_controller.sv',ip/'bank/bank_ownership_table.sv',ip/'bank/bank_port_router.sv',ip/'bank/bram_bank.sv',rtl/'attention_tensor_bank_subsystem.sv']
 packet=BASE/'modules/attention_tensor_control.json'
 if sha(packet)!='53fe7ef380ce28536cd9c48be01b1957230f7263bbf5c65bc8eb872cc6a38ec2':raise RuntimeError('packet identity changed')
 pins=json.loads(packet.read_text());pinned=dict(pins['common_contracts'])
 for key in ['isa','rtl_contract']:pinned[pins[key]['path']]=pins[key]['sha256']
 for path,digest in pinned.items():
  if sha(ROOT/path)!=digest:raise RuntimeError('pin changed '+path)
 audit=out/'generation_audit'
 run(['python3',BASE/'scripts/generate_tensor_config.py','--descriptor',BASE/'rtl_vectors/prefill/descriptor_table.json','--output-dir',audit],ROOT,out/'generation.log')
 if sha(audit/'attention_tensor_config_pkg.sv')!=sha(rtl/'attention_tensor_config_pkg.sv'):raise RuntimeError('active prefill configuration differs from generator')
 files=[*sources,packet,*[ROOT/p for p in pinned],BASE/'isa_program.py',BASE/'rtl_vectors/prefill/descriptor_table.json',BASE/'tb/tb_attention_control.sv',BASE/'scripts/run_control.py',BASE/'scripts/generate_tensor_config.py',BASE/'scripts/control_ooc_shell.sv',BASE/'scripts/control_lint.vlt',BASE/'scripts/control_lint_memory_stubs.sv',BASE/'scripts/control_ooc.tcl',ROOT/'designs/attention_int4_noscale_zcu104_r1/scripts/xsim_runtime.py']
 manifest={str(p.relative_to(ROOT)):sha(p) for p in files}
 (out/'manifest.json').write_text(json.dumps({'scope':'control-only; no executor arithmetic or full Attention acceptance','top':'control_ooc_shell','clock_ns':5,'configuration':{'command_read_latencies':[1,2],'late_fault_case':args.late_fault_case},'part':'xczu7ev-ffvc1156-2-e','sources':manifest},indent=2)+'\n')
 for path,digest in manifest.items():
  target=out/'source_snapshot'/path;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/path,target)
 run([VIVADO/'vivado','-version'],out,out/'version.log')
 if args.mode in ['sim','all']:
  for latency in [1,2]:
   work=out/f'xsim_l{latency}';work.mkdir()
   run([VIVADO/'xvlog','--sv',*sources,BASE/'tb/tb_attention_control.sv'],work,work/'compile.log')
   name=f'control_l{latency}'
   run([VIVADO/'xelab','tb_attention_control','-L','xpm','-generic_top',f'CMD_READ_LATENCY={latency}','-generic_top',f'LATE_FAULT_CASE={args.late_fault_case}','-s',name,'-timescale','1ns/1ps'],work,work/'elaborate.log')
   snapshot_run(work/'xsim.dir'/name/'xsimk',work,work/'simulation.log','ATTENTION_CONTROL_XSIM_PASS')
 if args.mode in ['lint','all']:
  lint_sources=[p for p in sources if p.name!='bram_bank.sv']
  run(['verilator','--lint-only','--sv','-Wall','--top-module','control_ooc_shell',BASE/'scripts/control_lint.vlt',*lint_sources,BASE/'scripts/control_lint_memory_stubs.sv',BASE/'scripts/control_ooc_shell.sv'],out,out/'lint.log')
 if args.mode in ['synth','all']:
  work=out/'ooc';work.mkdir();(work/'sources.tcl').write_text('\n'.join('read_verilog -sv {'+str(p)+'}' for p in [*sources,BASE/'scripts/control_ooc_shell.sv'])+'\n')
  run([VIVADO/'vivado','-mode','batch','-source',BASE/'scripts/control_ooc.tcl','-tclargs',work],work,work/'synthesis.log')
  if (work/'synthesis.log').read_text().splitlines().count('ATTENTION_CONTROL_OOC_PASS')!=1:raise RuntimeError('OOC PASS absent')
 for path,digest in manifest.items():
  if sha(ROOT/path)!=digest:raise RuntimeError('source changed during run '+path)
 (out/'result.json').write_text(json.dumps({'result':'PASS','mode':args.mode,'scope':'control-only mock executor; actual XPM memory pool','source_identity':'PASS','limitations':['no arithmetic/full Attention claim','no real DataMover or board','unplaced OOC timing only; explicit shared ascending array lint waiver']},indent=2)+'\n')
 print('ATTENTION_CONTROL_CHECK_PASS');print(out)
if __name__=='__main__':main()
