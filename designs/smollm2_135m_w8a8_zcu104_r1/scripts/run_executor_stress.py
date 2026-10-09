import json,subprocess,hashlib
from pathlib import Path
D=Path(__file__).resolve().parents[1];E=D/'evidence/int8_gemm_executor/stress';E.mkdir(parents=True,exist_ok=True)
rtl=['w8a8_fp32_pkg.sv','w8a8_fp32_mul.sv','fp32_bf16_epilogue.sv','int8_dot_core.sv','smollm2_int8_gemm_executor.sv']
cmd=['iverilog','-g2012','-s','executor_stress_tb','-o',str(E/'sim')]+[str(D/'rtl'/r) for r in rtl]+[str(D/'tb/executor_stress_tb.sv')]
p=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(E/'compile.log').write_text(p.stdout)
if p.returncode:raise SystemExit(p.stdout)
results=[]
for name,fault in [('golden_prefill32_Q_K576',0),('golden_prefill32_ATTN_SCORE_INT8',0),('direct_m_start31_N1',5),('direct_M17_N17_K1536',15)]:
 cmd=['vvp',str(E/'sim'),'+CASE='+str(D/'tb/executor_vectors'/name),f'+FAULT={fault}']
 p=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);(E/(name+f'_fault{fault}.log')).write_text(p.stdout);print(p.stdout.strip(),flush=True)
 if p.returncode or not any(l.startswith('EXECUTOR_PASS ') for l in p.stdout.splitlines()):raise SystemExit(1)
 results.append({'command':cmd,'exit':p.returncode})
(E/'report.json').write_text(json.dumps({'scope':'200cycle held output; badoperand while Brequest held until cycle200; latepartial64writes followednonfinite invalidation','source_sha256':hashlib.sha256((D/'rtl/smollm2_int8_gemm_executor.sv').read_bytes()).hexdigest(),'testbench_sha256':hashlib.sha256((D/'tb/executor_stress_tb.sv').read_bytes()).hexdigest(),'status':'PASS_STANDALONE_SIMULATION_ONLY','cases':results},indent=2)+'\n')
