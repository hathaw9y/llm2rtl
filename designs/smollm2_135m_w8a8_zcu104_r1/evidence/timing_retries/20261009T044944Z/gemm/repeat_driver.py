from pathlib import Path
import subprocess,json,hashlib
D=Path('/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1');E=Path(__file__).resolve().parent
cases=[]
for name,args in [('direct_m_start31_N1',['+REPEATS=3','+RESET_PROBE=1']),('golden_warm_decode32_ATTN_SCORE_INT8',['+REPEATS=2','+RESET_PROBE=1','+OLD_C=1']),('golden_warm_decode32_ATTN_VALUE_INT8',['+REPEATS=2','+RESET_PROBE=1','+OLD_C=1'])]:
 cmd=['vvp',str(E/'sim'),'+CASE='+str(D/'tb/executor_vectors'/name)]+args;p=subprocess.run(cmd,capture_output=True,text=True);(E/(name+'_repeat_reset.log')).write_text(p.stdout+p.stderr);print(p.stdout.strip(),flush=True)
 if p.returncode or not any(l.startswith('EXECUTOR_PASS ') for l in p.stdout.splitlines()):raise SystemExit(1)
 cases.append({'command':cmd,'exit':0})
(E/'repeat_cases.json').write_text(json.dumps({'source_sha256':hashlib.sha256((D/'rtl/smollm2_int8_gemm_executor.sv').read_bytes()).hexdigest(),'cases':cases},indent=2)+'\n')
