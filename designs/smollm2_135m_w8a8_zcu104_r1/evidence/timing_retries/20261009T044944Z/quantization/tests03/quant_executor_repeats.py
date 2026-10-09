from pathlib import Path
import subprocess,json,time,hashlib
D=Path(__file__).resolve().parents[1];E=Path('/home/shmin/llm2rtl/designs/smollm2_135m_w8a8_zcu104_r1/evidence/timing_retries/20261009T044944Z/quantization/tests03')
rtl=['w8a8_fp32_pkg.sv','w8a8_fp32_mul.sv','w8a8_fp32_div4.sv','w8a8_quant_lane4.sv','w8a8_dequant_lane4.sv','smollm2_quantization_executor.sv']
cmd=['iverilog','-g2012','-s','quant_executor_repeat_tb','-o',str(E/'repeat_sim')]+[str(D/'rtl'/r) for r in rtl]+[str(D/'tb/quant_executor_repeat_tb.sv')]
p=subprocess.run(cmd,capture_output=True,text=True);(E/'repeat_compile.log').write_text(p.stdout+p.stderr)
if p.returncode:raise SystemExit(p.stderr)
results=[]
for name in ['direct_A1_context_K576','direct_K1_layer29_prefix32_double_round','direct_DQ1_signed_zero','direct_P1_L33_masked_nonfinite']:
 for reset in ([0,1,2,3] if name in ['direct_A1_context_K576','direct_DQ1_signed_zero'] else [0,1]):
  cmd=['vvp',str(E/'repeat_sim'),'+CASE='+str(D/'tb/quant_executor_vectors'/name),'+RESET_PROBE='+str(reset)];t=time.monotonic();p=subprocess.run(cmd,capture_output=True,text=True,timeout=20)
  (E/f'repeat_{name}_{reset}.log').write_text(p.stdout+p.stderr);print(p.stdout.strip(),flush=True)
  if p.returncode:raise SystemExit(1)
  results.append({'case':name,'reset_probe':reset,'exit_code':p.returncode,'elapsed_seconds':time.monotonic()-t,'command':cmd})
(E/'repeat_cases.json').write_text(json.dumps({'source_sha256':hashlib.sha256((D/'rtl/smollm2_quantization_executor.sv').read_bytes()).hexdigest(),'tb_sha256':hashlib.sha256((D/'tb/quant_executor_repeat_tb.sv').read_bytes()).hexdigest(),'cases':results},indent=2)+'\n')
