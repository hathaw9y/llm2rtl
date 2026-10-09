#!/usr/bin/env python3
"""Run only caller-pinned frozen production modules, using isolated snapshots."""
import argparse,hashlib,json,pathlib,shutil,subprocess,time
HERE=pathlib.Path(__file__).resolve().parent;D=HERE.parents[1]
p=argparse.ArgumentParser();p.add_argument('--dispatcher-sha',required=True);p.add_argument('--bank-sha',required=True);p.add_argument('--run-name',required=True);a=p.parse_args()
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
rtl=[D/'rtl/smollm2_isa_dispatcher.sv',D/'rtl/smollm2_bank_controller.sv',D/'rtl/bank_ownership_table.sv']
assert sha(rtl[0])==a.dispatcher_sha,'dispatcher not frozen identity'
assert sha(rtl[1])==a.bank_sha,'controller not frozen identity'
orig_table=D.parents[1]/'ip/infrastructure/bank_ownership_table/rtl/bank_ownership_table.sv'
assert sha(rtl[2])==sha(orig_table),'ownership table byte identity mismatch'
run=HERE/a.run_name;run.mkdir(exist_ok=False);snap=run/'source_snapshot';snap.mkdir()
inputs=rtl+[HERE/'audit_infrastructure_tb.sv',HERE/'audit_decode_tb.sv']+sorted(HERE.glob('audit_*.hex'))
identity={str(x):sha(x) for x in inputs}
for src in inputs:shutil.copy2(src,snap/src.name)
for src in HERE.glob('audit_*.hex'):shutil.copy2(src,run/src.name)
contract_paths=[D/'contracts/infrastructure_rtl_port_binding.json',D/'contracts/infrastructure_boundary_clarifications.json',D/'contracts/isa_dispatcher_module_manifest.json',D/'contracts/bank_controller_module_manifest.json',D/'modules/isa_dispatcher.json',D/'modules/bank_controller.json']
contract_pins={str(x):sha(x) for x in contract_paths}
assert json.loads(contract_paths[1].read_text())['binding_sha256']==sha(contract_paths[0])
report={'contract_pins':contract_pins,'scope':'CONTROL_INTEGRATION_ONLY; mocked engine completion means synthetic quiescence, no DMA/tensor/numeric computation','source_before':identity,'source_snapshots':{x.name:sha(snap/x.name) for x in inputs},'commands':[]}
cmd=['iverilog','-g2012','-s','audit_infrastructure_tb','-o',str(run/'sim.vvp')]+[str(snap/x.name) for x in rtl]+[str(snap/'audit_infrastructure_tb.sv')]
decode_cmd=['iverilog','-g2012','-s','audit_decode_tb','-o',str(run/'decode.vvp'),str(snap/'smollm2_isa_dispatcher.sv'),str(snap/'audit_decode_tb.sv')]
for label,command in [('compile',cmd),('simulation',['vvp',str(run/'sim.vvp')]),('decode_compile',decode_cmd),('decode_simulation',['vvp',str(run/'decode.vvp')])]:
 t=time.time();result=subprocess.run(command,cwd=run,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
 (run/(label+'.log')).write_text(result.stdout);report['commands'].append({'name':label,'argv':command,'exit_code':result.returncode,'seconds':time.time()-t})
 if result.returncode:break
report['contract_pins_after']={str(x):sha(x) for x in contract_paths}
report['contracts_unchanged']=report['contract_pins']==report['contract_pins_after']
report['source_after']={str(x):sha(x) for x in inputs}
report['live_sources_unchanged']=report['source_before']==report['source_after']
report['source_bound_pass']=len(report['commands'])==4 and all(x['exit_code']==0 for x in report['commands']) and 'AUDIT_CONTROL_INTEGRATION_PASS' in (run/'simulation.log').read_text() and 'AUDIT_STATIC_DECODE_PASS' in (run/'decode_simulation.log').read_text()
report['status']='PASS_CONTROL_INTEGRATION' if report['source_bound_pass'] else 'FAILED'
(run/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'status':report['status'],'report':str(run/'report.json'),'live_sources_unchanged':report['live_sources_unchanged']}))
raise SystemExit(0 if report['source_bound_pass'] else 1)
