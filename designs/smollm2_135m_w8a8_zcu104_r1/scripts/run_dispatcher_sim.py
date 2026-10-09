"""Exact-source dispatcher tests; external engines/controller are control models."""
from pathlib import Path
import json, hashlib, subprocess
D=Path(__file__).resolve().parents[1]; E=D/'evidence/infrastructure_wave/dispatcher'
E.mkdir(exist_ok=True)
rtl=D/'rtl/smollm2_isa_dispatcher.sv';tb=D/'tb/dispatcher_tb.sv'
refs=[rtl,tb,D/'contracts/infrastructure_rtl_port_binding.json',D/'contracts/isa_dispatcher_module_manifest.json',D/'evidence/infrastructure_wave/isa_decode_vectors.json',Path(__file__)]
hashes={str(p.relative_to(D)):hashlib.sha256(p.read_bytes()).hexdigest() for p in refs}
cases=json.loads(refs[4].read_text())['cases']
(E/'decode_records.hex').write_text(''.join(c['hex128']+'\n' for c in cases))
(E/'decode_expect.hex').write_text(''.join(str(int(c.get('normative_expect_issue_or_control_accept',c['expect_issue_or_control_accept'])))+'\n' for c in cases))
commands=[['verilator','--lint-only','-Wall','--top-module','smollm2_isa_dispatcher',str(rtl)],['iverilog','-g2012','-s','dispatcher_tb','-o',str(E/'sim'),str(rtl),str(tb)],['vvp',str(E/'sim')]]
result=[]
for cmd,name in zip(commands,['final_lint.log','final_compile.log','final_simulation.log']):
 run=subprocess.run(cmd,cwd=E,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=90)
 (E/name).write_text(run.stdout);result.append({'command':cmd,'exit_code':run.returncode,'log':name})
 if run.returncode!=0:
  (E/'self_test_report.json').write_text(json.dumps({'status':'FAIL','source_hashes':hashes,'runs':result},indent=2)+'\n')
  raise SystemExit(run.returncode)
assert all(hashlib.sha256(p.read_bytes()).hexdigest()==hashes[str(p.relative_to(D))] for p in refs)
assert 'DISPATCHER_PASS vectors=2957 directed=22 random_fragments=50' in run.stdout
report={'status':'PASS_STANDALONE_CONTROL_MODELS','source_hashes':hashes,'runs':result,'static_vectors':2957,'directed_scenarios':22,'random_fragments':50,'source_unchanged':True,'limitations':['Clean mocked engine completions are a contract assumption, not tensor/DMA quiescence proof','Control model does not establish real controller integration','No physical bank memory/router/coverage service/board claims']}
(E/'self_test_report.json').write_text(json.dumps(report,indent=2)+'\n');print(run.stdout,end='')
