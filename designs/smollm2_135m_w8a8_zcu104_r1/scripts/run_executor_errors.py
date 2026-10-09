import json,subprocess
from pathlib import Path
D=Path(__file__).resolve().parents[1];E=D/'evidence/int8_gemm_executor'
subprocess.run(['python3',str(D/'scripts/run_executor_sim.py'),'COMPILE_ONLY'],check=True)
results=[]
for fault in range(1,16):
 name='golden_decode_lm_head_last_N' if fault==14 else 'direct_M17_N17_K1536' if fault==15 else 'golden_warm_decode32_ATTN_SCORE_INT8' if fault==11 else 'golden_warm_decode32_ATTN_VALUE_INT8' if fault==12 else 'direct_m_start31_N1'
 cmd=['vvp',str(E/'sim'),'+CASE='+str(D/'tb/executor_vectors'/name),f'+FAULT={fault}']
 p=subprocess.run(cmd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 (E/f'error_{fault:02d}.log').write_text(p.stdout);print(p.stdout.strip(),flush=True)
 results.append({'fault':fault,'command':cmd,'exit':p.returncode})
 if p.returncode or not any(l.startswith('EXECUTOR_PASS ') for l in p.stdout.splitlines()):raise SystemExit(1)
(E/'error_cases.json').write_text(json.dumps(results,indent=2)+'\n')
