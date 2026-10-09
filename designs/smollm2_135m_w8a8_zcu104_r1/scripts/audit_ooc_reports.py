import json,re,hashlib
from pathlib import Path
D=Path(__file__).resolve().parents[1];R=D/'evidence/ooc_runs/20261009T042510Z'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
records={}
for name,top,marker in [('gemm','smollm2_int8_gemm_executor','EXECUTOR_OOC_SYNTH_COMPLETE'),('quantization','smollm2_quantization_executor','QUANT_EXECUTOR_OOC_SYNTH_COMPLETE')]:
 E=R/name;log=(E/'vivado.log').read_text();assert sum(l.strip()==marker for l in log.splitlines())==1
 util=(E/'utilization_synth.rpt').read_text();tim=(E/'timing_synth.rpt').read_text()
 assert top in util and 'Vivado v.2025.2' in util and 'xczu7ev-ffvc1156-2-e' in util
 assert re.search(r'executor_clk\s+\{0\.000 2\.500\}\s+5\.000\s+200\.000',tim)
 exitcode=int((E/'exit_code.txt').read_text()) if name=='gemm' else json.loads((E/'process_result.json').read_text())['exit_code'];assert exitcode==0
 row=next(l for l in util.splitlines() if l.lstrip().startswith('| '+top+' '));parts=[x.strip() for x in row.split('|')[1:-1]]
 vals=list(map(int,parts[2:]));resources=dict(zip(['LUT_total','LUT_logic','LUTRAM','SRL','FF','RAMB36','RAMB18','URAM','DSP'],vals))
 numeric=next(l for l in tim.splitlines() if re.match(r'^\s+-?\d+\.\d+\s+-?\d+\.\d+\s+\d+\s+\d+\s+-?\d+\.\d+',l));v=numeric.split()
 keys=['WNS_ns','TNS_ns','setup_failing_endpoints','setup_total_endpoints','WHS_ns','THS_ns','hold_failing_endpoints','hold_total_endpoints','WPWS_ns','TPWS_ns','pulse_failing_endpoints','pulse_total_endpoints']
 timing={k:(int(x) if 'endpoints' in k else float(x)) for k,x in zip(keys,v)}
 for k in ['unconstrained_internal_endpoints','no_input_delay','no_output_delay','no_clock','loops','latch_loops']:
  timing[k]=int(re.search(r'checking '+k+r' \((\d+)\)',tim).group(1))
 before=json.loads((E/('source_hashes_before.json' if name=='gemm' else 'source_before.json')).read_text());assert all(sha(Path(p))==s for p,s in before.items())
 records[name]={'top':top,'process_exit_code':exitcode,'source_pins_verified':before,'actual_executed_marker_count':1,'resources':resources,'timing':timing,'clock_only_boundary_constraints':True,'setup_5ns_status':'FAIL' if timing['WNS_ns']<0 or timing['setup_failing_endpoints'] else 'PASS','raw_report_sha256':{p.name:sha(p) for p in E.glob('*') if p.is_file() and p.suffix in ['.rpt','.xdc','.tcl','.json','.dcp','.log','.tsv','.txt']}}
mapping={}
for line in (R/'gemm/inspection/physical_mapping.tsv').read_text().splitlines()[1:]:
 scope,primitive,count=line.split('\t');mapping.setdefault(scope,{})[primitive]=int(count)
assert mapping['dots/*']['DSP48E2']==256 and mapping['*psum*']['FDRE']==49152 and mapping['*b_panels*']['FDRE']==8192
assert int((R/'gemm/inspection/exit_code.txt').read_text())==0
assert sum(l.strip()=='GEMM_NETLIST_INSPECTION_COMPLETE' for l in (R/'gemm/inspection/stdout.log').read_text().splitlines())==1
assert json.loads((R/'gemm/source_hashes_before.json').read_text())==json.loads((R/'gemm/source_hashes_after.json').read_text())
assert json.loads((R/'quantization/source_before.json').read_text())==json.loads((R/'quantization/source_after.json').read_text())
records['gemm']['physical_mapping']=mapping
records['gemm']['physical_mapping_note']='A low maps11RAMB36+1RAMB18; A high maps19392RAMD64E+48RAM64M despite block attribute; resultFIFO9RAMB36. Distributed mapping/timing warnings material; logical buffer capacity is not physical packed BRAM capacity.'
records['quantization']['physical_mapping_note']='Hierarchical utilization retains quantization/div LUT datapath and four distinct DQ FP32 multiply children,2DSP each. Quant top20DSP includes8DQ and12control.'
for name in records:
 E=R/name
 for fn in ['drc_synth.rpt','methodology_synth.rpt']:
  txt=(E/fn).read_text(); rows=[]
  for line in txt.splitlines():
   if re.match(r'^\| (?:SYNTH|TIMING|DPIP|DPOP)-',line):
    parts=[x.strip() for x in line.split('|')[1:-1]];rows.append({'rule':parts[0],'severity':parts[1],'description':parts[2],'checks':int(parts[3])})
  records[name][fn]=rows
records['gemm']['worst_path']={'source':'ar_r_reg[2]/C','destination':'error_r_reg[3]/R','data_delay_ns':50.858,'logic_levels':422,'CARRY8_levels':328,'diagnostic_inference':'Unpipelined variable response row/chunk division by astride_r is a likely contributor; actual timing report path is authoritative.'}
records['quantization']['worst_path']={'source':'width_r_reg[1]/C','destination':'max_r_reg[0][0]/CE','data_delay_ns':49.224,'logic_levels':407,'CARRY8_levels':317,'diagnostic_inference':'Unpipelined variable division/modulo in group_for likely contributes; arithmetic divider child not established as worst path.'}
auth=json.loads((R/'authorization.json').read_text());assert all(sha(D/p)==h for p,h in auth['frozen_modules'].items())
records['gemm']['inspection_artifact_sha256']={str(p.relative_to(R)):sha(p) for p in (R/'gemm/inspection').glob('*') if p.is_file()}
records['gemm']['script_constraint_pins_verified']=json.loads((R/'gemm/script_constraint_hashes.json').read_text())
for p,h in records['gemm']['script_constraint_pins_verified'].items():assert sha(D.parents[1]/p)==h
assert (R/'quantization/original_script_reference.tcl').read_bytes()==(D/'scripts/quant_executor_ooc.tcl').read_bytes()
report={'schema':'llm2rtl.independent_ooc_audit.v1','status':'SYNTHESIS_COMPLETED_SETUP_TIMING_FAILED','read_only_audit':True,'tool':'Vivado2025.2','part':'xczu7ev-ffvc1156-2-e','clock_period_ns':5.0,'authorization_sha256':sha(R/'authorization.json'),'runs':records,'excluded_claims':['routed200MHz closure','native/control I/O boundary timing','combined board resource fit','BIT/HWH/XSA production','hardware runtime'],'old_functional_reports_modified_by_auditor':False}
(R/'independent_audit.json').write_text(json.dumps(report,indent=2)+'\n');print('INDEPENDENT_OOC_REPORT_WRITTEN')
