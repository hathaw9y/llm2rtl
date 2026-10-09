from pathlib import Path
import subprocess,json,hashlib
D=Path('/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1');E=Path(__file__).resolve().parent;out=[]
for name in ['direct_QK_M17_L33_scale_groups','direct_QK_L1_padded16','direct_PV_L1_tail','direct_PV_L1024_INT32_max','direct_m_start31_N1','direct_M17_N17_K1536','golden_decode_lm_head_last_N']:
 cmd=['vvp',str(E/'sim'),'+CASE='+str(D/'tb/executor_vectors'/name)];p=subprocess.run(cmd,capture_output=True,text=True);(E/(name+'_directed.log')).write_text(p.stdout+p.stderr);print(p.stdout.strip(),flush=True)
 if p.returncode or not any(l.startswith('EXECUTOR_PASS ') for l in p.stdout.splitlines()):raise SystemExit(1)
 out.append({'case':name,'command':cmd,'exit':0})
(E/'directed_cases.json').write_text(json.dumps({'source_sha256':hashlib.sha256((D/'rtl/smollm2_int8_gemm_executor.sv').read_bytes()).hexdigest(),'cases':out},indent=2)+'\n')
