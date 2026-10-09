#!/usr/bin/env python3
"""Read-only source-bound actual fabric/XPM simulation; require final ordered runtime closure."""
import argparse,hashlib,json,pathlib,shutil,subprocess,time
H=pathlib.Path(__file__).resolve().parent;D=H.parents[1];R=D.parents[1]
TOOL=pathlib.Path('/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--closure',required=True);p.add_argument('--closure-sha',required=True);p.add_argument('--top-sha',required=True);p.add_argument('--run',required=True);p.add_argument('--tb',default='audit_fabric_negative_tb.sv');p.add_argument('--module',default='audit_fabric_negative_tb');p.add_argument('--marker',default='AUDIT_FABRIC_NEGATIVE_PASS');a=p.parse_args()
closure=pathlib.Path(a.closure).resolve();assert sha(closure)==a.closure_sha
c=json.loads(closure.read_text());pins={x['path']:x['sha256'] for x in c['ordered_sources']}
tops=[x for x in pins if pathlib.Path(x).name=='smollm2_execution_fabric.sv'];assert len(tops)==1 and pins[tops[0]]==a.top_sha,'Need exact frozen composed runtime closure, not historical child-only packet'
run=H/a.run;run.mkdir();src=run/'src';src.mkdir();sources=[]
for name,expected in pins.items():
 original=R/name;assert sha(original)==expected,name
 target=src/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(original,target);sources.append(target)
tb=H/a.tb;(src/a.tb).parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(tb,src/a.tb);sources.append(src/a.tb)
assetfiles=[x for x in (H/'fabric_negative_vectors').iterdir() if x.is_file()]+list(tb.parent.glob('*.bytehex'))
assets={str(x.relative_to(R)):sha(x) for x in assetfiles}
snapshot={str(x.relative_to(src)):sha(x) for x in src.rglob('*') if x.is_file()}
(run/'source_before.json').write_text(json.dumps({'pins':pins,'closure':str(closure),'closure_sha256':sha(closure),'snapshot':snapshot,'fixture_assets':assets},indent=2)+'\n')
records=[]
def execute(stage,argv,limit):
 start=time.time()
 with (run/(stage+'.log')).open('w') as log:out=subprocess.run(argv,cwd=run,stdout=log,stderr=subprocess.STDOUT,timeout=limit)
 records.append({'stage':stage,'argv':argv,'exit_code':out.returncode,'seconds':time.time()-start,'log_sha256':sha(run/(stage+'.log'))});(run/'process_results.json').write_text(json.dumps(records,indent=2)+'\n')
 assert out.returncode==0,stage
execute('compile',[str(TOOL/'xvlog'),'-sv']+[str(x) for x in sources],300)
execute('elaborate',[str(TOOL/'xelab'),a.module,'-L','xpm','-s','audit_fabric','--timescale','1ns/1ps'],300)
execute('simulate',['python',str(R/'ip/infrastructure/datamover_engine/scripts/run_xsimk.py'),str(run/'xsim.dir/audit_fabric/xsimk'),a.marker],600)
log=(run/'simulate.log').read_text();markers=[x for x in log.splitlines() if x.startswith('@"'+a.marker)]
assert len(markers)==1
for token in ['Fatal:','FATAL:','Error:','ERROR:']:assert token not in log,token
assert snapshot=={str(x.relative_to(src)):sha(x) for x in src.rglob('*') if x.is_file()}
after={name:sha(R/name) for name in pins};assert after==pins
assert all(sha(R/name)==v for name,v in assets.items())
report={'status':'FUNCTIONAL_PASS_SOURCE_BOUND','scope':'Actual composed execution fabric, all frozen real children, real XPM native/command memories; external DDR/DataMover AXIS environment only. No routed/board/fullmodel claim.','top_sha256':a.top_sha,'closure_sha256':a.closure_sha,'source_pins':pins,'source_after':after,'processes':records,'executed_marker':markers,'fixture_assets':assets}
(run/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'status':report['status'],'executed_marker':markers}))
