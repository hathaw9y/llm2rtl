#!/usr/bin/env python3
import argparse,hashlib,json,pathlib,re,subprocess,sys
p=argparse.ArgumentParser();p.add_argument('--module',choices=['dma_transaction_bridge','command_bram'],required=True);p.add_argument('--run-dir',required=True);a=p.parse_args()
D=pathlib.Path(__file__).resolve().parents[1];root=D.parents[1];run=pathlib.Path(a.run_dir).resolve();run.mkdir(parents=True,exist_ok=True)
if (run/'process_result.json').exists():raise SystemExit('Refusing to overwrite a completed run')
module=json.loads((D/'modules'/f'{a.module}.json').read_text());sources=[root/n for n in module['child_RTL_pins']]+[D/'rtl'/f'smollm2_{a.module}.sv',D/'scripts'/f'{a.module}_ooc.tcl']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
before={str(p):sha(p) for p in sources};(run/'source_hashes_before.json').write_text(json.dumps(before,indent=2));(run/'sources').mkdir(exist_ok=True)
for s in sources:(run/'sources'/s.name).write_bytes(s.read_bytes())
argv=['/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin/vivado','-mode','batch','-source',str(sources[-1]),'-log','vivado.log','-journal','vivado.jou'];(run/'command.json').write_text(json.dumps({'argv':argv,'cwd':str(run)},indent=2))
with (run/'launch.log').open('w') as f:ret=subprocess.run(argv,cwd=run,stdout=f,stderr=subprocess.STDOUT).returncode
(run/'process_result.json').write_text(json.dumps({'exit_code':ret},indent=2));after={str(p):sha(p) for p in sources};(run/'source_hashes_after.json').write_text(json.dumps(after,indent=2));print('vivado exit',ret,flush=True)
if ret:sys.exit(ret)
assert before==after
log=(run/'vivado.log').read_text();markers=[(i,l) for i,l in enumerate(log.splitlines(),1) if l.startswith('OOC_COMPLETE_EXECUTED '+a.module+' ')]
assert len(markers)==1
T=(run/'timing_summary.rpt').read_text();line=next(l for l in T.splitlines() if re.match(r'^\s+(?:-?\d+\.\d+|NA)\s+(?:-?\d+\.\d+|NA)\s+(?:\d+|NA)\s+(?:\d+|NA)\s+(?:-?\d+\.\d+|NA)',l));keys=['WNS_ns','TNS_ns','setup_failing_endpoints','setup_total_endpoints','WHS_ns','THS_ns','hold_failing_endpoints','hold_total_endpoints','WPWS_ns','TPWS_ns','pulse_failing_endpoints','pulse_total_endpoints'];timing={k:(None if v=='NA' else (int(v) if 'endpoints' in k else float(v))) for k,v in zip(keys,line.split())}
for n in ['unconstrained_internal_endpoints','no_input_delay','no_output_delay','no_clock','loops','latch_loops']:
 x=re.search('checking '+n+r' \((\d+)\)',T);timing[n]=int(x.group(1)) if x else None
U=(run/'utilization_hier.rpt').read_text();top='smollm2_'+a.module;row=next(l for l in U.splitlines() if l.lstrip().startswith('| '+top+' '));parts=[x.strip() for x in row.split('|')[1:-1]];resources=dict(zip(['LUT_total','LUT_logic','LUTRAM','SRL','FF','RAMB36','RAMB18','URAM','DSP'],map(int,parts[2:])))
report={'module':a.module,'top':top,'part':'xczu7ev-ffvc1156-2-e','tool':'Vivado2025.2','clock_ns':5,'actual_exit_code':ret,'actual_executed_marker_line':markers[0][0],'marker':markers[0][1],'source_hashes_before':before,'source_hashes_after':after,'resources':resources,'timing':timing,'setup_hold_status':'NOT_APPLICABLE_NO_INTERNAL_REG_TO_REG_PATHS' if timing['WNS_ns'] is None else ('PASS' if timing['WNS_ns']>=0 and timing['WHS_ns']>=0 and timing['WPWS_ns']>=0 and all(timing[k]==0 for k in ['setup_failing_endpoints','hold_failing_endpoints','pulse_failing_endpoints']) else 'FAIL'),'boundary_constraint_scope':'Clock-only OOC; native/control/DataMover I/O boundary delays not constrained; no board/routed timing claim','artifact_sha256':{str(p.name):sha(p) for p in run.iterdir() if p.is_file() and p.suffix in ['.rpt','.dcp','.xdc','.log','.tcl']}}
(run/'module_ooc.json').write_text(json.dumps(report,indent=2));print(json.dumps({'resources':resources,'timing':timing,'status':report['setup_hold_status']},indent=2))
