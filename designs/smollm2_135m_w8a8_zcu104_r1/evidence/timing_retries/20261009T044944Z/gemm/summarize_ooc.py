from pathlib import Path
import json,hashlib,re,sys
R=Path(sys.argv[1]).resolve();before=json.loads((R/'source_hashes_before.json').read_text());ap=R/'source_hashes_after.json'
if ap.exists():after=json.loads(ap.read_text())
else:
 after={p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in before};ap.write_text(json.dumps(after,indent=2)+'\n')
assert before==after
log=(R/'stdout.log').read_text().splitlines();marker=[i+1 for i,l in enumerate(log) if l=='EXECUTOR_OOC_SYNTH_COMPLETE'];assert len(marker)==1;assert (R/'exit_code.txt').read_text().strip()=='0'
lines=(R/'timing_synth.rpt').read_text().splitlines();nums=None
for i,l in enumerate(lines):
 bits=l.split()
 if len(bits)==12:
  try:vals=[float(x) for x in bits]
  except ValueError:continue
  nums=vals;tl=i+1;break
assert nums is not None
names=['WNS_ns','TNS_ns','setup_fail','setup_total','WHS_ns','THS_ns','hold_fail','hold_total','WPWS_ns','TPWS_ns','pulse_fail','pulse_total'];timing=dict(zip(names,nums));passed=nums[0]>=0 and nums[4]>=0 and nums[8]>=0 and nums[2]==nums[6]==nums[10]==0
util=(R/'utilization_synth.rpt').read_text().splitlines();u={}
for i,l in enumerate(util):
 pieces=[x.strip() for x in l.strip('|').split('|')]
 if len(pieces)==11 and pieces[0]=='smollm2_int8_gemm_executor':
  u=dict(zip(['LUT','logicLUT','LUTRAM','SRL','FF','RAMB36','RAMB18','URAM','DSP'],[int(x) for x in pieces[2:]]));ul=i+1;break
assert u
mapping={};mp=R/'inspection/physical_mapping.tsv'
if mp.exists():
 for l in mp.read_text().splitlines()[1:]:sc,pr,n=l.split('\t');mapping.setdefault(sc,{})[pr]=int(n)
paths={}
for key,regex in [('source',r'^  Source:\s+(.*)'),('destination',r'^  Destination:\s+(.*)'),('data_delay',r'^  Data Path Delay:\s+(.*)'),('logic_levels',r'^  Logic Levels:\s+(.*)')]:
 for i,l in enumerate(lines):
  m=re.match(regex,l)
  if m:paths[key]={'text':m[1],'line':i+1};break
checks={}
for name in ['drc_synth.rpt','methodology_synth.rpt']:
 t=(R/name).read_text();section=t[t.index('Checks found:'):].split('2. REPORT DETAILS')[0];items=[]
 for l in section.splitlines():
  p=[x.strip() for x in l.strip('|').split('|')]
  if len(p)==4 and p[1] in ['Warning','Critical Warning','Error'] and p[-1].isdigit():items.append({'rule':p[0],'severity':p[1],'checks':int(p[-1])})
 checks[name]=items
files=[p for p in R.rglob('*') if p.is_file() and p.name!='ooc_summary.json' and '.Xil' not in str(p)]
s={'status':'OOC_POST_SYNTH_TIMING_PASS' if passed else 'OOC_SYNTHESIS_COMPLETE_TIMING_FAILED','cwd':str(R),'invocation':json.loads((R/'invocation.json').read_text()),'executed_marker_line':marker[0],'exit_code':0,'top_sha256':next(h for p,h in before.items() if p.endswith('/smollm2_int8_gemm_executor.sv')),'source_unchanged_during_run':True,'resources':u,'timing':timing,'timing_table_line':tl,'util_table_line':ul,'worst_path':paths,'physical_mapping':mapping,'checks':checks,'hashes':{str(p.relative_to(R)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files},'limitations':['Post-synthesis estimated timing only; not placed/routed or board signoff','Native boundary I/O delays unconstrained;5ns internal clock retained','Original functional/synthesis reports retained']}
(R/'ooc_summary.json').write_text(json.dumps(s,indent=2)+'\n');print(json.dumps({'status':s['status'],'resources':u,'timing':timing},indent=2))
