#!/usr/bin/env python3
"""Exact-source module golden regression in Vivado XSIM; no board claim."""
import argparse, hashlib, json, shutil, subprocess, time
from pathlib import Path
from run_executor_sim import SOURCES, FINAL_PASS, BASE, ROOT
BIN=Path('/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin')
def main():
 p=argparse.ArgumentParser();p.add_argument('module',choices=['fp32','nonlinear','rope','vector','rmsnorm','softmax','gemm']);p.add_argument('work',type=Path);a=p.parse_args()
 out=a.work.resolve();out.mkdir(parents=True,exist_ok=False);src=out/'source';src.mkdir();(out/'designs').symlink_to(ROOT/'designs',target_is_directory=True)
 files=[BASE/'rtl'/f for f in SOURCES]+[BASE/'tb'/f'tb_qwen_{a.module}.sv']
 golden=BASE/'evidence'/f'{a.module}_run001';rom=BASE/'evidence/fp32_run001'
 for f in files:shutil.copyfile(f,src/f.name)
 inputs=files+list(golden.glob('*.mem'))+list(rom.glob('*.mem'))
 manifest={'module':a.module,'scope':'Module golden, protocol and error regression only; no board timing or physical execution proof.','source_and_vector_sha256':{str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs}}
 (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');start=time.monotonic()
 def run(cmd,name):
  with (out/name).open('w') as log:r=subprocess.run(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT)
  if r.returncode:raise RuntimeError(name+' failed')
 run([str(BIN/'xvlog'),'--sv']+[str(src/f.name) for f in files],'compile.log')
 run([str(BIN/'xelab'),f'tb_qwen_{a.module}','-s','qwen_executor_packet','--debug','typical','--timescale','1ns/1ps'],'elaborate.log')
 vector=golden/'vectors.mem' if a.module=='nonlinear' else golden
 run([str(BIN/'xsim'),'qwen_executor_packet','-runall','-testplusarg','VECTORS='+str(vector)],'simulation.log')
 text=(out/'simulation.log').read_text();passed=FINAL_PASS[a.module] in text and 'Fatal:' not in text and 'FATAL' not in text
 (out/'result.json').write_text(json.dumps({'status':'passed_module_simulation' if passed else 'failed','seconds':time.monotonic()-start,'manifest_sha256':hashlib.sha256((out/'manifest.json').read_bytes()).hexdigest()},indent=2)+'\n');print(text[-2500:],flush=True)
 if not passed:raise SystemExit(1)
if __name__=='__main__':main()
