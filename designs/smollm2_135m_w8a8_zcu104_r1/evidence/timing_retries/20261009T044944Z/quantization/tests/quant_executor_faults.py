from pathlib import Path
import subprocess,json,time,hashlib
D=Path(__file__).resolve().parents[1];E=Path('/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/timing_retries/20261009T044944Z/quantization/tests')
rtl=['w8a8_fp32_pkg.sv','w8a8_fp32_mul.sv','w8a8_fp32_div4.sv','w8a8_quant_lane4.sv','w8a8_dequant_lane4.sv','smollm2_quantization_executor.sv']
cmd=['iverilog','-g2012','-s','quant_executor_fault_tb','-o',str(E/'fault_sim')]+[str(D/'rtl'/r) for r in rtl]+[str(D/'tb/quant_executor_fault_tb.sv')]
p=subprocess.run(cmd,capture_output=True,text=True);(E/'fault_compile.log').write_text(p.stdout+p.stderr)
if p.returncode:raise SystemExit(p.stderr)
K='direct_K1_layer29_prefix32_double_round';V='direct_V17_layer29_prefix32_groups';DQ='direct_DQ1_signed_zero';P='direct_P1_L1_all_negative'
results=[]
for fault,name in [(1,K),(2,V),(3,K),(4,K),(5,K),(6,V),(7,DQ),(8,DQ),(9,DQ),(10,K),(11,K),(12,K),(13,K),(14,K),(15,K),(16,K),(17,P),(18,DQ)]:
 cmd=['vvp',str(E/'fault_sim'),'+CASE='+str(D/'tb/quant_executor_vectors'/name),'+FAULT='+str(fault)];t=time.monotonic()
 try:p=subprocess.run(cmd,capture_output=True,text=True,timeout=20)
 except subprocess.TimeoutExpired as e:(E/f'fault{fault}.log').write_text((e.stdout or b'').decode()+'\nTIMEOUT');raise
 (E/f'fault{fault}.log').write_text(p.stdout+p.stderr);print(p.stdout.strip(),flush=True)
 if p.returncode:raise SystemExit(1)
 results.append({'fault':fault,'case':name,'exit_code':p.returncode,'elapsed_seconds':time.monotonic()-t,'command':cmd})
(E/'fault_cases.json').write_text(json.dumps({'source_sha256':hashlib.sha256((D/'rtl/smollm2_quantization_executor.sv').read_bytes()).hexdigest(),'tb_sha256':hashlib.sha256((D/'tb/quant_executor_fault_tb.sv').read_bytes()).hexdigest(),'cases':results},indent=2)+'\n')
