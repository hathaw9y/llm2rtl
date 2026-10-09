"""Fresh independent actual-XPM simulation of a parent-approved frozen closure.
Closure JSON: ordered_sources=[{path: repository-relative,sha256: exact}],
prerequisites_verified=true; no inferred or wildcard source substitutions.
"""
import argparse,hashlib,json,pathlib,shutil,subprocess,sys
HERE=pathlib.Path(__file__).resolve().parent;DESIGN=HERE.parents[1];ROOT=DESIGN.parents[1]
TOOL=pathlib.Path('/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin')
DIRECT=ROOT/'ip/infrastructure/datamover_engine/scripts/run_xsimk.py'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v):p.write_text(json.dumps(v,indent=2)+'\n')
def execute(argv,cwd,name,results):
 with (cwd/(name+'.log')).open('w') as f:r=subprocess.run(list(map(str,argv)),cwd=cwd,stdout=f,stderr=subprocess.STDOUT)
 results.append({'argv':list(map(str,argv)),'cwd':str(cwd),'exit_code':r.returncode,'raw_log':name+'.log'});dump(cwd/'commands.json',results)
 if r.returncode:raise RuntimeError(f'{name} exit {r.returncode}; raw log preserved')
 return (cwd/(name+'.log')).read_text(errors='replace')
def main():
 a=argparse.ArgumentParser();a.add_argument('--source-closure',type=pathlib.Path,required=True);a.add_argument('--suite',choices=['pingpong_quant_gemm','projection_fragments','attention_L1','attention_L33','attention_L1024'],required=True);a.add_argument('--run',required=True);opt=a.parse_args()
 closure=json.loads(opt.source_closure.read_text());assert closure['prerequisites_verified'] is True
 pins=json.loads((HERE/'fixture_pins.json').read_text())
 for rel,h in pins.items():assert sha(ROOT/rel)==h,rel
 before={x['path']:sha(ROOT/x['path']) for x in closure['ordered_sources']}
 for x in closure['ordered_sources']:assert before[x['path']]==x['sha256'],x
 names={pathlib.Path(x['path']).name for x in closure['ordered_sources']}
 assert {'smollm2_execution_fabric.sv','smollm2_native_bank_pool.sv','smollm2_int8_gemm_executor.sv','smollm2_quantization_executor.sv','smollm2_isa_dispatcher.sv','smollm2_bank_controller.sv','bram_bank.sv','uram_bank.sv'}<=names
 assert not any('stub' in n or 'declaration_only' in n for n in names)
 run=HERE/'runs'/opt.suite/opt.run;run.mkdir(parents=True,exist_ok=False)
 dump(run/'source_before.json',before);shutil.copy2(opt.source_closure,run/'approved_source_closure.json')
 ordered=[]
 for x in closure['ordered_sources']:
  src=ROOT/x['path'];dst=run/'source_snapshot'/x['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst);assert sha(dst)==x['sha256'];ordered.append(dst)
 prepared=HERE/'prepared'/opt.suite;fixture=run/'fixtures';shutil.copytree(prepared,fixture)
 tb=fixture/'audit_fabric_tb.sv';tb.write_text(tb.read_text().replace(str(prepared),str(fixture)))
 dump(run/'tb_and_asset_pins.json',{str(p.relative_to(run)):sha(p) for p in fixture.iterdir() if p.is_file()})
 cmds=[];status='FAIL_OR_INCOMPLETE';failure=None
 try:
  execute([TOOL/'xvlog','-sv',*ordered,tb],run,'compile',cmds)
  execute([TOOL/'xelab','audit_fabric_tb','-L','xpm','-s','audit_fabric_tb'],run,'elaborate',cmds)
  marker='PASS_INDEPENDENT_FABRIC_NUMERICAL_'+opt.suite
  raw=execute([sys.executable,DIRECT,run/'xsim.dir/audit_fabric_tb/xsimk',marker],run,'simulate',cmds)
  lines=[]
  for line in raw.splitlines():
   if line.startswith('@"'):
    try:lines.extend(json.loads(line[1:]).splitlines())
    except (ValueError,TypeError):pass
   else:lines.append(line)
  (run/'executed_display.log').write_text('\n'.join(lines)+'\n')
  assert marker in lines,'Actual standalone executed PASS missing'
  assert any(l.startswith('NUMERICAL_COUNTS ') for l in lines)
  status='PASS_SCOPED_NUMERICAL_EXTERNAL_DDR_ACTUAL_XPM'
 except Exception as e:failure=str(e)
 after={x['path']:sha(ROOT/x['path']) for x in closure['ordered_sources']}
 if before!=after:status='FAIL_STALE_SOURCE';failure='DUT source changed during run'
 dump(run/'source_after.json',after)
 dump(run/'report.json',{'status':status,'suite':opt.suite,'top':'smollm2_execution_fabric','source_closure_sha256':sha(opt.source_closure),'source_before':before,'source_after':after,'fixture_original_pins':pins,'commands':cmds,'failure':failure,'tool':'Vivado2025.2 actual XPM','scope':'ISA/external vendor AXIS numerical verification only','overlap_witness':'Separate read-only hook needed after owner source freeze; base numerical PASS does not claim overlap witness','forbidden_claims':['routed timing','board execution','full model inference/quality','integration OOC gate']})
 print(status,run)
 if status!='PASS_SCOPED_NUMERICAL_EXTERNAL_DDR_ACTUAL_XPM':raise SystemExit(1)
if __name__=='__main__':main()
