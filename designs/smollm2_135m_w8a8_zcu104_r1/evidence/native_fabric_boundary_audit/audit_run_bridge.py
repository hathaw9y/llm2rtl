#!/usr/bin/env python3
import argparse,hashlib,json,pathlib,shutil,subprocess,time
H=pathlib.Path(__file__).resolve().parent;D=H.parents[1];R=D.parents[1];TOOL=pathlib.Path('/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin');sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
a=argparse.ArgumentParser();a.add_argument('--top-sha',required=True);a.add_argument('--run',required=True);a.add_argument('--top-source');args=a.parse_args()
pins=json.loads((D/'modules/dma_transaction_bridge.json').read_text())['child_RTL_pins'];pins[str((D/'rtl/smollm2_dma_transaction_bridge.sv').relative_to(R))]=args.top_sha
run=H/args.run;run.mkdir();src=run/'src';src.mkdir()
for p,h in pins.items():
 source=pathlib.Path(args.top_source).resolve() if args.top_source and pathlib.Path(p).name=='smollm2_dma_transaction_bridge.sv' else R/p
 assert sha(source)==h,p;shutil.copyfile(source,src/pathlib.Path(p).name)
shutil.copyfile(H/'audit_dma_bridge_tb.sv',src/'audit_dma_bridge_tb.sv');snapshot={p.name:sha(p) for p in src.iterdir()};(run/'source_before.json').write_text(json.dumps({'pins':pins,'snapshot':snapshot,'binding_sha256':sha(D/'contracts/dma_transaction_bridge_rtl_binding.json')},indent=2)+'\n')
records=[]
def execute(label,argv,timeout):
 start=time.time()
 with (run/(label+'.log')).open('w') as log:p=subprocess.run(argv,cwd=run,stdout=log,stderr=subprocess.STDOUT,timeout=timeout)
 records.append({'stage':label,'argv':argv,'exit_code':p.returncode,'seconds':time.time()-start,'log_sha256':sha(run/(label+'.log'))});(run/'process_results.json').write_text(json.dumps(records,indent=2)+'\n');assert p.returncode==0,label
files=[src/'datamover_engine_pkg.sv']+[p for p in src.iterdir() if p.name not in ['datamover_engine_pkg.sv','audit_dma_bridge_tb.sv']]+[src/'audit_dma_bridge_tb.sv']
execute('compile',[str(TOOL/'xvlog'),'-sv']+[str(p) for p in files],180)
execute('elaborate',[str(TOOL/'xelab'),'audit_dma_bridge_tb','-L','xpm','-s','audit_dma','--timescale','1ns/1ps'],180)
execute('simulate',['python',str(R/'ip/infrastructure/datamover_engine/scripts/run_xsimk.py'),str(run/'xsim.dir/audit_dma/xsimk'),'AUDIT_DMA_BRIDGE_PASS'],180)
text=(run/'simulate.log').read_text();assert 'AUDIT_DMA_BRIDGE_PASS' in text
for word in ['Fatal:','FATAL:','Error:','ERROR:']:assert word not in text
assert snapshot=={p.name:sha(p) for p in src.iterdir()}
after={p:sha(R/p) for p in pins};report={'status':'FUNCTIONAL_PASS','scope':'Actual bridge/reused DataMover and adapters with external native/controller BFMs; no physical bank/DDR/fabric or OOC claim','source_pins':pins,'live_sources_unchanged':pins==after,'processes':records,'executed_marker':[x for x in text.splitlines() if 'AUDIT_DMA_BRIDGE_PASS' in x]};(run/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
