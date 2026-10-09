#!/usr/bin/env python3
"""Independent immutable real-XPM leaf replay; requires owner-tested source pins."""
import argparse,hashlib,json,os,pathlib,shutil,subprocess,time
ROOT=pathlib.Path(__file__).resolve().parents[4]
DESIGN=ROOT/'designs/smollm2_135m_w8a8_zcu104_r1'
HERE=pathlib.Path(__file__).resolve().parent
TOOL=pathlib.Path('/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin')
FILES=['bram_bank.sv','uram_bank.sv','smollm2_bank_payload.sv','smollm2_bank_coverage.sv','smollm2_native_bank_pool.sv']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
a=argparse.ArgumentParser();a.add_argument('--pins',required=True,help='JSON {RTL basename:tested SHA256}, exactly five files');a.add_argument('--run',required=True);args=a.parse_args()
pins=json.loads(pathlib.Path(args.pins).read_text());assert set(pins)==set(FILES),pins
run=HERE/args.run;run.mkdir();src=run/'src';src.mkdir()
actual={f:sha(DESIGN/'rtl'/f) for f in FILES};assert actual==pins,(actual,pins)
for f in FILES:shutil.copyfile(DESIGN/'rtl'/f,src/f)
shutil.copyfile(HERE/'audit_native_leaf_tb.sv',src/'audit_native_leaf_tb.sv')
(run/'source_before.json').write_text(json.dumps({'tested_pins':pins,'snapshot_hashes':{p.name:sha(p) for p in src.iterdir()},'binding':sha(DESIGN/'contracts/native_bank_pool_rtl_binding.json'),'clarifications':sha(DESIGN/'contracts/native_bank_pool_boundary_clarifications.json')},indent=2)+'\n')
results=[]
def execute(label,argv,timeout):
 start=time.time()
 with (run/(label+'.log')).open('w') as log:
  proc=subprocess.run(argv,cwd=run,stdout=log,stderr=subprocess.STDOUT,timeout=timeout)
 results.append({'step':label,'argv':argv,'exit_code':proc.returncode,'seconds':time.time()-start,'log_sha256':sha(run/(label+'.log'))})
 (run/'process_results.json').write_text(json.dumps(results,indent=2)+'\n')
 assert proc.returncode==0,label
execute('compile',[str(TOOL/'xvlog'),'-sv']+[str(src/f) for f in FILES]+[str(src/'audit_native_leaf_tb.sv')],180)
execute('elaborate',[str(TOOL/'xelab'),'audit_native_leaf_tb','-L','xpm','-s','audit_leaf'],300)
execute('simulate',['python',str(ROOT/'ip/infrastructure/datamover_engine/scripts/run_xsimk.py'),str(run/'xsim.dir/audit_leaf/xsimk'),'AUDIT_NATIVE_LEAF_PASS'],1200)
text=(run/'simulate.log').read_text();assert 'AUDIT_NATIVE_LEAF_PASS' in text
for bad in ['Fatal:','FATAL:','Error:','ERROR:']:assert bad not in text,bad
assert {p.name:sha(p) for p in src.iterdir()}==json.loads((run/'source_before.json').read_text())['snapshot_hashes']
after={f:sha(DESIGN/'rtl'/f) for f in FILES}
report={'status':'FUNCTIONAL_PASS','scope':'Real native bank/XPM byte transport and exact coverage only; OOC and full execution fabric not certified','source_pins':pins,'live_sources_after':after,'live_sources_unchanged':after==pins,'processes':results,'marker':[line for line in text.splitlines() if 'AUDIT_NATIVE_LEAF_PASS' in line]}
(run/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
