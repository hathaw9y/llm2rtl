#!/usr/bin/env python3
"""Read-only raw-report audit; never invokes Vivado or edits implementation files."""
import argparse,pathlib,json,hashlib,re
h=pathlib.Path(__file__).resolve().parent;d=h.parents[1];r=d.parents[1]
p=argparse.ArgumentParser();p.add_argument('module');p.add_argument('run');p.add_argument('--out',required=True);a=p.parse_args()
x=d/'evidence/infrastructure_wave'/a.module/a.run;rep=json.loads((x/'module_ooc_synthesis_report.json').read_text());sha=lambda z:hashlib.sha256(z.read_bytes()).hexdigest();checks={}
checks['all_artifact_hashes']=all(sha(x/f)==v for f,v in rep['artifact_sha256'].items())
checks['source_identity_before_after']=rep['source_before_sha256']==rep['source_after_sha256']
checks['current_rtl_matches']=all(sha(r/f)==v for f,v in rep['source_before_sha256'].items())
log=(x/'vivado.log').read_text();tcl=(x/'ooc_reference.tcl').read_text();tim=(x/'timing_summary.rpt').read_text();util=(x/'utilization.rpt').read_text()
checks['actual_marker']=rep['executed_standalone_marker'] in log.splitlines()
checks['reported_exit0']=rep['actual_exit_code']==0
checks['tool_build']='Vivado v2025.2' in log and 'SW Build 6299465' in log
checks['part_top_mode']=all(z in tcl for z in [rep['top'],'xczu7ev-ffvc1156-2-e','-mode out_of_context'])
checks['pre_synth_xdc']=tcl.index('read_xdc')<tcl.index('synth_design') and log.index('# read_xdc')<log.index('# synth_design')
xdc=(x/'clock_reference.xdc').read_text();checks['constraint5ns_only']=bool(re.search(r'create_clock[^\n]*-period\s+5(?:\.0+)?',xdc)) and not any(k in xdc for k in ['false_path','multicycle','clock_groups','set_max_delay','set_min_delay'])
start=tim.index('WNS(ns)');line=next(l for l in tim[start:].splitlines()[1:] if len(l.split())==12 and all(re.fullmatch(r'-?\d+(?:\.\d+)?',v) for v in l.split()))
keys=['wns_ns','tns_ns','setup_failing_endpoints','setup_total_endpoints','whs_ns','ths_ns','hold_failing_endpoints','hold_total_endpoints','wpws_ns','tpws_ns','pw_failing_endpoints','pw_total_endpoints'];vals=line.split();actual={k:(float(v) if 'ns' in k else int(v)) for k,v in zip(keys,vals)}
checks['raw_timing_matches']=actual==rep['timing']
checks['all_timing_pass']=all(actual[k]>=0 for k in ['wns_ns','whs_ns','wpws_ns']) and all(actual[k]==0 for k in ['tns_ns','ths_ns','tpws_ns','setup_failing_endpoints','hold_failing_endpoints','pw_failing_endpoints'])
checks['raw_clock5ns']=bool(re.search(r'clk\s+\{0\.000 2\.500\}\s+5\.000\s+200\.000',tim))
resources={}
for name,row in [('LUT','CLB LUTs*'),('FF','CLB Registers'),('DSP','DSPs'),('BRAM','Block RAM Tile'),('URAM','URAM')]:
 m=re.search(r'\|\s*'+re.escape(row)+r'\s*\|\s*(\d+)',util);assert m,row;resources[name]=int(m[1])
checks['raw_resources_match']=all(rep['resources'][k]==v for k,v in resources.items())
checks['unconstrained_internal0']='checking unconstrained_internal_endpoints (0)' in tim
missing={key:int(re.search(r'checking '+name+r' \((\d+)\)',tim)[1]) for key,name in [('input','no_input_delay'),('output','no_output_delay')]}
checks['missing_delays_match']=missing['input']==rep['unconstrained']['missing_input_delays'] and missing['output']==rep['unconstrained']['missing_output_delays']
report={'status':'PASS_STANDALONE_INTERNAL_POST_SYNTH_5NS' if all(checks.values()) else 'FAILED','checks':checks,'top':rep['top'],'source_pins':rep['source_before_sha256'],'primary_report':str(x/'module_ooc_synthesis_report.json'),'primary_report_sha256':sha(x/'module_ooc_synthesis_report.json'),'timing':actual,'resources':resources,'clock_ns':5.0,'missing_external_delays':missing,'scope':'Unplaced standalone OOC synthesis with pre-synthesis clock constraint. No combined infrastructure timing, external interface timing, placement/routing, hardware or tensor-memory claim.','command':['python3',str(pathlib.Path(__file__).resolve()),a.module,a.run,'--out',a.out]}
(h/a.out).write_text(json.dumps(report,indent=2)+'\n');print(report['status']);assert all(checks.values()),checks
