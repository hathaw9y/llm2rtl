import json,subprocess,sys,os,hashlib,time
from pathlib import Path
D=Path(__file__).resolve().parents[1];E=Path('/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/timing_retries/20261009T044944Z/quantization/tests');E.mkdir(parents=True,exist_ok=True)
B=json.loads((D/'contracts/quantization_rtl_port_binding.json').read_text())['executor']
manifest=json.loads((D/'tb/quant_executor_vectors/manifest.json').read_text())
for case in manifest['cases']:
 P=D/case['path'];c=json.loads((P/'case.json').read_text());ds=[b['descriptor'] for b in c['banks']]
 for role,bank in zip('ABC',c['banks']):
  target=P/(role+'.hex')
  if not target.exists():target.symlink_to(bank['initial_file'])
 widths={'cmd_desc_present':('present',1),'cmd_profiles':('profile',5),'cmd_rows':('rows',11),'cmd_cols':('cols',16),'cmd_positions':('position',10),'cmd_layers':('layer',5),'cmd_desc_generations':('generation',32),'cmd_data_valid':('data_valid',1),'cmd_scale_valid':('scale_valid',1),'cmd_desc_busy':('busy',1),'cmd_desc_owner':('owner',5)}
 record=int(c['hex128'],16);vals={'cmd_opcode':record>>124,'cmd_payload':record&((1<<112)-1),'cmd_bank_ids':sum(x['bank']<<(4*i) for i,x in enumerate(c['banks'])),'cmd_transaction_id':c['transaction_id'],'cmd_generations':sum(x<<(32*i) for i,x in enumerate(c['generations']))}
 vals.update({n:sum(d[key]<<(i*w) for i,d in enumerate(ds)) for n,(key,w) in widths.items()})
 lines=[' '.join(format(v,'x') for v in [*[b['capacity_bytes']//16 for b in c['banks']],c['expected_status'],int(c['producer_begin_expected']),c['producer_generation'],c['producer_profile'],c['producer_rows'],c['producer_cols'],c['producer_position'],c['producer_layer']])]
 for n in ['cmd_opcode', 'cmd_payload', 'cmd_bank_ids', 'cmd_transaction_id', 'cmd_generations', 'cmd_desc_present', 'cmd_profiles', 'cmd_rows', 'cmd_cols', 'cmd_positions', 'cmd_layers', 'cmd_desc_generations', 'cmd_data_valid', 'cmd_scale_valid', 'cmd_desc_busy', 'cmd_desc_owner', 'cmd_b7_static_valid', 'cmd_embedding_lanes', 'cmd_embedding_lane_valid']:
  lines.append(format(vals.get(n,c.get(n,0)),'x'))
 (P/'stim.hex').write_text('\n'.join(lines)+'\n')
rtl=['w8a8_fp32_pkg.sv','w8a8_fp32_mul.sv','w8a8_fp32_div4.sv','w8a8_quant_lane4.sv','w8a8_dequant_lane4.sv','smollm2_quantization_executor.sv']
cmd=['iverilog','-g2012','-s','quant_executor_tb','-o',str(E/'sim')]+[str(D/'rtl'/r) for r in rtl]+[str(D/'tb/quant_executor_tb.sv')]
source_hashes={str(f.relative_to(D)):hashlib.sha256(f.read_bytes()).hexdigest() for f in [*[D/'rtl'/r for r in rtl],D/'tb/quant_executor_tb.sv']}
p=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(E/'compile.log').write_text(p.stdout)
if p.returncode:raise SystemExit(p.stdout)
case_results=[]
for case in manifest['cases']:
 if len(sys.argv)>1 and sys.argv[1] not in case['name']:continue
 cmd=['vvp',str(E/'sim'),'+CASE='+str(D/case['path'])];started=time.monotonic();p=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 (E/(case['name']+'.log')).write_text(p.stdout);print(p.stdout.strip(),flush=True)
 if p.returncode or not any(l.startswith('QUANT_EXECUTOR_PASS ') for l in p.stdout.splitlines()):raise SystemExit(1)

 case_results.append({'case':case['name'],'command':cmd,'exit_code':p.returncode,'elapsed_seconds':time.monotonic()-started,'executed_marker':[l for l in p.stdout.splitlines() if l.startswith('QUANT_EXECUTOR_PASS ')][0]})
if case_results:
 (E/'simulation_cases.json').write_text(json.dumps({'source_hashes':source_hashes,'compile_command':cmd if False else ['iverilog','-g2012','-s','quant_executor_tb','-o',str(E/'sim')]+[str(D/'rtl'/r) for r in rtl]+[str(D/'tb/quant_executor_tb.sv')],'compile_exit':0,'cases':case_results},indent=2)+'\n')
