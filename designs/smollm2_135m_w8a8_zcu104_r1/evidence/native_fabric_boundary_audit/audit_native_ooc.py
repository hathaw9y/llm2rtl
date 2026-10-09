#!/usr/bin/env python3
import json,pathlib,re,hashlib
H=pathlib.Path(__file__).resolve().parent;D=H.parents[1];O=D/'evidence/native_bank_pool/ooc01';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
pins=json.loads((H/'leaf_tested_pins.json').read_text());assert all(sha(D/'rtl'/n)==h for n,h in pins.items());assert all(sha(D/'evidence/native_bank_pool/source_final'/n)==h for n,h in pins.items())
log=(O/'vivado.log').read_text();marker='PASS_NATIVE_BANK_POOL_OOC_SYNTH_EXECUTED';assert len(re.findall('^'+marker+'$',log,re.M))==1
assert log.index('# read_xdc ')<log.index('Command: synth_design')
tcl=(O/'ooc_reference.tcl').read_text();xdc=(O/'clock_reference.xdc').read_text();assert tcl.index('read_xdc')<tcl.index('synth_design');assert 'set_false_path' not in tcl+xdc and 'set_multicycle_path' not in tcl+xdc
assert xdc=='create_clock -name clk -period 5.000 [get_ports clk]\n'
assert sha(O/'ooc_reference.tcl')==sha(D/'scripts/native_bank_pool/ooc.tcl');assert sha(O/'clock_reference.xdc')==sha(D/'scripts/native_bank_pool/clock.xdc')
timing=(O/'timing_summary.rpt').read_text();numeric=re.search(r'^\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+)\s+(\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+)\s+(\d+)\s+(\d+\.\d+)\s+(\d+\.\d+)\s+(\d+)\s+(\d+)\s*$',timing,re.M);assert numeric
values=numeric.groups();assert values==('0.142','0.000','0','20013','0.073','0.000','0','20013','1.800','0.000','0','13329'),values
clock=(O/'clocks.rpt').read_text();assert re.search(r'^clk\s+5\.000\s+\{0\.000 2\.500\}',clock,re.M)
assert 'xczu7ev-ffvc1156-2-e' in (O/'utilization.rpt').read_text();assert 'Vivado v.2025.2' in timing
assert '0 pins that are not constrained for maximum delay' in timing
mapping=[]
for line in (O/'mapping.tsv').read_text().splitlines()[1:]:
 f=line.split('\t')
 if f[0]=='blackboxes':assert f[1]=='0';continue
 mapping.append([int(v) for v in f])
assert len(mapping)==16;totals=[sum(r[j] for r in mapping) for j in range(1,7)];assert totals==[110,0,74,100,2,0],totals
usage=(O/'utilization.rpt').read_text()
for label,n in [('CLB LUTs*',43721),('CLB Registers',12831),('RAMB36/FIFO*',210),('RAMB18',2),('URAM',74),('DSPs',2)]:assert re.search(r'\|\s*'+re.escape(label)+r'\s*\|\s*'+str(n)+r'\s*\|',usage),(label,n)
raw={p.name:sha(p) for p in O.iterdir() if p.is_file() and p.suffix in ['.rpt','.tsv','.dcp','.log','.tcl','.xdc']}
report={'status':'RAW_OOC_PASS_PROCESS_CLOSURE_PENDING','scope':'Standalone post-synthesis internal5ns native leaf only','source_pins':pins,'clock_before_synthesis':True,'clock_ns':5,'part':'xczu7ev-ffvc1156-2-e','tool':'Vivado2025.2 build6299465','executed_marker_line':log.splitlines().index(marker)+1,'timing':dict(zip(['WNS','TNS','setup_failures','setup_endpoints','WHS','THS','hold_failures','hold_endpoints','WPWS','TPWS','pulse_failures','pulse_endpoints'],values)),'resources':{'LUT':43721,'FF':12831,'DSP':2,'RAMB36':210,'RAMB18':2,'URAM':74},'per_bank_mapping':mapping,'payload_mapping':{'RAMB36':110,'RAMB18':0,'URAM':74},'coverage_mapping':{'RAMB36':100,'RAMB18':2,'URAM':0},'blackboxes':0,'missing_input_delays':4328,'missing_output_delays':4106,'internal_unconstrained':0,'drc_warnings':7,'drc_errors':0,'methodology_warnings':1000,'methodology_scope':'TIMING-18 missing boundary I/O delay capped1000','raw_hashes':raw,'pending':'Owner actual process exit/argv and source/Tcl/XDC before-after metadata','limitations':['No external I/O delay constraints','No routed timing','No combined fabric/resource fit claim','No board or full model signoff']}
(H/'native_leaf_ooc_audit.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'])
