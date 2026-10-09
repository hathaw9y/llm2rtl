#!/usr/bin/env python3
"""Run evaluator-owned T01 tests against candidate RTL. Never reads candidate tests."""
import argparse,hashlib,json,os,shutil,subprocess,sys,threading
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--candidate-root',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--suite',choices=['public','hidden','all'],default='all');p.add_argument('--record-baseline',action='store_true');p.add_argument('--structural',action='store_true');a=p.parse_args()
evaldir=Path(__file__).resolve().parents[1]/'evaluator/t01';a.out=a.out.resolve();a.out.mkdir(parents=True,exist_ok=True)
rtl=a.candidate_root.resolve()/'designs/smollm2_135m_bf16_zcu104_r1/rtl/smollm2_gemm_systolic_wide_executor.sv'
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
manifest=json.loads((evaldir/'manifest.json').read_text()) if (evaldir/'manifest.json').exists() else None
if a.record_baseline:
 if sha(rtl)!=sha(evaldir/'baseline.sv'):raise SystemExit('Golden recording requires exact frozen baseline RTL.')
else:
 if not manifest:raise SystemExit('Evaluator golden not frozen.')
 if manifest.get('runner_sha256') and sha(Path(__file__))!=manifest['runner_sha256']:raise SystemExit('Evaluator runner integrity mismatch.')
 requested_suites=['public','hidden'] if a.suite=='all' else [a.suite]
 for name,digest in manifest['files'].items():
  if name!='tb_t01.sv' and not any(name.startswith(suite+'/') for suite in requested_suites):continue
  if sha(evaldir/name)!=digest:raise SystemExit(f'Evaluator integrity mismatch: {name}')
for suite in ['public','hidden'] if a.suite=='all' else [a.suite]:shutil.copytree(evaldir/suite,a.out/suite,dirs_exist_ok=True)
def run(cmd,log,timeout=600):
 with (a.out/log).open('w') as f:
  proc=subprocess.run(cmd,cwd=a.out,stdout=f,stderr=subprocess.STDOUT,timeout=timeout)
 if proc.returncode:raise RuntimeError(f'{log} failed; see {a.out/log}')
run(['xvlog','-sv',str(rtl),str(evaldir/'tb_t01.sv')],'xvlog.log')
run(['xelab','tb_t01','--timescale','1ns/1ps','-s','t01_sim'],'xelab.log')
results=[]
for suite in ['public','hidden'] if a.suite=='all' else [a.suite]:
 # Native kernel command protocol avoids broken runall wrapper in Vivado 2025.2.
 env=os.environ.copy();vivado=Path(os.environ.get('XILINX_VIVADO','/media/admin1/backup/tools/Xilinx/2025.2/Vivado'));env['LD_LIBRARY_PATH']=str(vivado/'lib/lnx64.o')
 args=[str(a.out/'xsim.dir/t01_sim/xsimk'),'-testplusarg',f'SUITE={suite}']
 if a.record_baseline:args+=['-testplusarg','RECORD']
 proc=subprocess.Popen(args,cwd=a.out,env=env,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1);lines=[]
 watchdog=threading.Timer(900,proc.kill);watchdog.start()
 def until(token):
  while True:
   line=proc.stdout.readline();lines.append(line)
   if not line:raise RuntimeError(f'XSIM exited before {token}: '+''.join(lines[-15:]))
   if token in line:return
 try:
  until('=elaboration-done');proc.stdin.write('-exec-run\n');proc.stdin.flush();until('reason="run-complete"');proc.stdin.write('-exec-continue\n');proc.stdin.flush();until('reason="finish"');proc.stdin.write('-gdb-exit\n');proc.stdin.flush();tail,_=proc.communicate(timeout=30);lines.append(tail)
 finally:
  watchdog.cancel()
  (a.out/f'{suite}_xsim.log').write_text(''.join(lines))
  if proc.poll() is None:proc.kill()
 passed=proc.returncode==0 and 'PASS T01 suite' in ''.join(lines) and 'Fatal:' not in ''.join(lines)
 results.append(dict(suite=suite,passed=passed,case_count=len(json.loads((evaldir/suite/'cases.json').read_text()))))
 if not passed:raise SystemExit(f'{suite} failed; see log')
 if a.record_baseline:
  for f in (a.out/suite).glob('*_expected.hex'):shutil.copy2(f,evaldir/suite/f.name)
report={'candidate_rtl':str(rtl),'candidate_sha256':sha(rtl),'functional':results,'structural':'not run','limitations':['Executor level only; no full model, dispatcher, board synthesis or hardware qualification.','Attention VALUE uses deterministic synthetic P; no softmax coupling.']}
if a.structural:
 tcl=f'''read_verilog -sv {{{rtl}}}
synth_design -top smollm2_gemm_systolic_wide_executor -part xczu7ev-ffvc1156-2-e -mode out_of_context -flatten_hierarchy none
create_clock -period 10 [get_ports aclk]
set pes [get_cells -hier -filter {{ORIG_REF_NAME == smollm2_bf16_wide_pe || REF_NAME == smollm2_bf16_wide_pe}}]
set f [open structural_cells.txt w]
foreach pe $pes {{puts $f $pe}}
close $f
report_utilization -file utilization.rpt
report_timing_summary -file timing.rpt
puts "T01_PE_COUNT [llength $pes]"
'''
 (a.out/'structural.tcl').write_text(tcl);run(['vivado','-mode','batch','-source','structural.tcl'],'structural.log',1800)
 cells=(a.out/'structural_cells.txt').read_text().splitlines();import re
 coords=[re.search(r'gen_row\[(\d+)\].*gen_col\[(\d+)\]',c) for c in cells];shape={(int(m[1]),int(m[2])) for m in coords if m}
 report['structural']={'pe_count':len(cells),'shape_verified':len(shape)==128 and shape=={(r,c) for r in range(8) for c in range(16)},'passed':len(cells)==128 and shape=={(r,c) for r in range(8) for c in range(16)},'scope':'OOC shared executor hierarchy; board-wide extra arrays require board audit.'}
(a.out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
if a.record_baseline:
 files={str(f.relative_to(evaldir)):sha(f) for f in evaldir.rglob('*') if f.is_file() and f.name!='manifest.json' and '__pycache__' not in f.parts}
 (evaldir/'manifest.json').write_text(json.dumps({'baseline_sha256':sha(evaldir/'baseline.sv'),'runner_sha256':sha(Path(__file__)),'generator_sha256':sha(Path(__file__).with_name('t01_generate.py')),'files':files},indent=2)+'\n')

if a.structural and not report['structural']['passed']:raise SystemExit(1)
