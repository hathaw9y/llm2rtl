#!/usr/bin/env python3
"""Run one exact-source module regression; preserve sources, vectors and logs."""
import argparse,hashlib,json,shutil,subprocess,time
from pathlib import Path
BASE=Path(__file__).resolve().parents[1];ROOT=BASE.parents[1]
SOURCES=['qwen_fp32_pkg.sv','qwen_fp32_pipe.sv','qwen_bf16_product_pipe.sv','qwen_nonlinear_scalar.sv','qwen_reduce16_scalar.sv','qwen_dot16x4.sv','qwen_gemm_executor.sv','qwen_rope_executor.sv','qwen_rmsnorm_executor.sv','qwen_softmax_executor.sv','qwen_vector_executor.sv']
FINAL_PASS={'fp32':'PASS FP32 arithmetic/conversion=','nonlinear':'PASS nonlinear bit-exact','rope':'PASS RoPE shape/alias/nonfinite errors, response backpressure, reset','vector':'PASS vector all14','rmsnorm':'PASS RMSNorm payload/error/backpressure cases','softmax':'PASS Softmax payload/error/backpressure/reset','gemm':'PASS GEMM payload/error/backpressure/reset'}
def main():
 p=argparse.ArgumentParser();p.add_argument('module',choices=['fp32','nonlinear','rope','vector','rmsnorm','softmax','gemm']);p.add_argument('run');a=p.parse_args()
 out=BASE/'evidence'/a.run;out.mkdir(exist_ok=False);(out/'source').mkdir()
 files=[BASE/'rtl'/f for f in SOURCES]+[BASE/'tb'/f'tb_qwen_{a.module}.sv']
 for f in files:shutil.copyfile(f,out/'source'/f.name)
 golden=BASE/'evidence'/f'{a.module}_run001';vector=golden/'vectors.mem' if a.module=='nonlinear' else golden
 rom=BASE/'evidence/fp32_run001'
 pinned={str(f.relative_to(BASE)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files+list(golden.glob('*.mem'))+list(rom.glob('*.mem'))}
 (out/'manifest.json').write_text(json.dumps({'source_and_vector_sha256':pinned,'module':a.module,'scope':'Module simulation only, no board evidence.'},indent=2)+'\n')
 started=time.monotonic();compile_cmd=['iverilog','-g2012','-Wall','-s',f'tb_qwen_{a.module}','-o',str(out/'sim')]+[str(out/'source'/f.name) for f in files]
 with (out/'compile.log').open('w') as log:subprocess.run(compile_cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
 with (out/'simulation.log').open('w') as log:result=subprocess.run(['vvp',str(out/'sim'),'+VECTORS='+str(vector)],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
 text=(out/'simulation.log').read_text();passed=result.returncode==0 and FINAL_PASS[a.module] in text and 'FATAL' not in text
 (out/'result.json').write_text(json.dumps({'status':'passed_module_simulation' if passed else 'failed','returncode':result.returncode,'seconds':time.monotonic()-started,'source_manifest_sha256':hashlib.sha256((out/'manifest.json').read_bytes()).hexdigest()},indent=2)+'\n')
 print(a.module,text[-1400:],flush=True)
 if not passed:raise SystemExit(1)
if __name__=='__main__':main()
