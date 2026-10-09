import json,re,sys,hashlib
from pathlib import Path
E=Path(__file__).resolve().parent;R=E.parent;D=E.parents[3];iteration=sys.argv[1] if len(sys.argv)>1 else '01';only=sys.argv[2] if len(sys.argv)>2 else None;records={};sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for n,top,mark in [('gemm','smollm2_int8_gemm_executor','EXECUTOR_OOC_SYNTH_COMPLETE'),('quantization','smollm2_quantization_executor','QUANT_EXECUTOR_OOC_SYNTH_COMPLETE')]:
 if only and n!=only:continue
 p=R/n/('ooc'+iteration);log=(p/'vivado.log').read_text();assert sum(l.strip()==mark for l in log.splitlines())==1
 exitcode=int((p/'exit_code.txt').read_text()) if n=='gemm' else json.loads((p/'process_result.json').read_text())['exit_code'];assert exitcode==0
 before=json.loads((p/('source_hashes_before.json' if n=='gemm' else 'source_before.json')).read_text());after=json.loads((p/('source_hashes_after.json' if n=='gemm' else 'source_after.json')).read_text());assert before==after
 snap=E/n/('source_snapshot' if iteration=='01' else 'candidate'+iteration+'/source_snapshot')
 for original,h in before.items():
  rel=Path(original).relative_to(D)
  captured=snap/rel
  if str(rel).startswith('rtl/'):
   assert captured.exists() and sha(captured)==h,(captured,h)
 timing=(p/'timing_synth.rpt').read_text();util=(p/'utilization_synth.rpt').read_text();assert top in util and 'Vivado v.2025.2' in util and 'xczu7ev-ffvc1156-2-e' in util
 assert re.search(r'executor_clk\s+\{0\.000 2\.500\}\s+5\.000\s+200\.000',timing)
 row=next(l for l in timing.splitlines() if re.match(r'^\s+-?\d+\.\d+\s+-?\d+\.\d+\s+\d+\s+\d+\s+-?\d+\.\d+',l));keys=['WNS_ns','TNS_ns','setup_failures','setup_endpoints','WHS_ns','THS_ns','hold_failures','hold_endpoints','WPWS_ns','TPWS_ns','PW_failures','PW_endpoints'];t={k:int(v) if not k.endswith('_ns') else float(v) for k,v in zip(keys,row.split())}
 for k in ['no_clock','unconstrained_internal_endpoints','no_input_delay','no_output_delay','loops','latch_loops']:t[k]=int(re.search(r'checking '+k+r' \((\d+)\)',timing).group(1))
 resrow=next(l for l in util.splitlines() if l.lstrip().startswith('| '+top+' '));v=[x.strip() for x in resrow.split('|')[1:-1]][2:];res=dict(zip(['LUT','LogicLUT','LUTRAM','SRL','FF','RAMB36','RAMB18','URAM','DSP'],map(int,v)))
 assert 'Timing constraints are not met.' in timing if t['setup_failures'] or t['hold_failures'] or t['PW_failures'] else 'All user specified timing constraints are met.' in timing
 hierarchy=[]
 for line in util.splitlines():
  parts=[x.strip() for x in line.split('|')[1:-1]]
  if len(parts)==11 and all(v.isdigit() for v in parts[2:]):hierarchy.append({'instance':parts[0],'module':parts[1],'resources':dict(zip(['LUT','LogicLUT','LUTRAM','SRL','FF','RAMB36','RAMB18','URAM','DSP'],map(int,parts[2:])))})
 if n=='gemm':assert next(h for h in hierarchy if h['instance']=='dots')['resources']['DSP']==256
 records[n]={'hierarchy':hierarchy,'source_before_after_unchanged':True,'source_pins':before,'archived_source_match':True,'top':top,'process_exit':exitcode,'actual_marker_count':1,'tool':'Vivado2025.2','part':'xczu7ev-ffvc1156-2-e','clock_period_ns':5.0,'resources':res,'timing':t,'status':'POST_SYNTH_TIMING_FAIL' if t['setup_failures'] or t['hold_failures'] or t['PW_failures'] else 'POST_SYNTH_INTERNAL_TIMING_PASS','hashes':{x.name:sha(x) for x in p.iterdir() if x.is_file() and x.suffix in ['.rpt','.xdc','.tcl','.json','.dcp','.log']}}
result={'stage':'independent_post_synthesis_OOC_audit','iteration':iteration,'runs':records,'functional_reports':'Separate exact-source audit reports; no historical top PASS inheritance','excluded':['routed200MHzclosure','unconstrained native/control interface timing','combinedboardfit','physicalboarddeployment'],'no_RTL_or_contract_edits':True}
(E/('ooc'+iteration+('' if only is None else '_'+only)+'_audit.json')).write_text(json.dumps(result,indent=2)+'\n');print('RETRY_OOC_AUDITED',iteration)
