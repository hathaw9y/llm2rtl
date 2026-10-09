"""Run independent core vectors and self-checking simulation in isolated packet dir."""
import hashlib,json,subprocess
from pathlib import Path
D=Path(__file__).resolve().parents[1];E=D/'evidence/int8_dot_core'
E.mkdir(parents=True,exist_ok=True)
commands=[['python3',str(D/'scripts/core_vectors.py')],['iverilog','-g2012','-s','tb_int8_dot_core','-o',str(E/'sim'),str(D/'rtl/int8_dot_core.sv'),str(D/'tb/tb_int8_dot_core.sv')],['vvp',str(E/'sim')],['verilator','--lint-only','--unroll-count','2048','-Wall','--top-module','int8_dot_core',str(D/'rtl/int8_dot_core.sv')]]
results=[]
for i,cmd in enumerate(commands):
 p=subprocess.run(cmd,cwd=E,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 (E/f'sim_stage_{i}.log').write_text(p.stdout)
 results.append({'command':cmd,'exit_code':p.returncode,'log':f'sim_stage_{i}.log'})
 if p.returncode:raise SystemExit(p.stdout)
 if i==2 and not any(line.startswith('CORE_PASS inputs=9718 outputs=250 ') for line in p.stdout.splitlines()):raise SystemExit('missing executed CORE_PASS')
files=['rtl/int8_dot_core.sv','tb/tb_int8_dot_core.sv','scripts/core_vectors.py','scripts/run_core_sim.py','evidence/int8_dot_core/inputs.txt','evidence/int8_dot_core/expected.txt']
report={'module_id':'int8_dot_core','status':'PASS_LOCAL_SIMULATION_AND_LINT_ONLY','contract_sha256':hashlib.sha256((D/'contracts/datapaths/int8_dot_core.json').read_bytes()).hexdigest(),'source_sha256':hashlib.sha256((D/files[0]).read_bytes()).hexdigest(),'file_hashes':{f:hashlib.sha256((D/f).read_bytes()).hexdigest() for f in files},'commands':results,'accepted_steps':9718,'compared_results':250,'nominal_latency_accepted_edge_to_result_edge':5,'registered_stages':6,'issue_interval_unstalled':1,'cases':['K1536 maxima ±127','signed cancellation','96 interleaved contexts','row0 consecutive K steps','N1..N16','random bubbles and result stalls','reset live pipeline and no stale result'],'synthesis':'NOT_RUN_PENDING_DESIGNATED_MACHINE_AUTHORIZATION','forbidden_claims':['full executor PASS','full model PASS','board timing or deployment']}
(E/'kernel_report.json').write_text(json.dumps(report,indent=2)+'\n')
print(report['status'])
