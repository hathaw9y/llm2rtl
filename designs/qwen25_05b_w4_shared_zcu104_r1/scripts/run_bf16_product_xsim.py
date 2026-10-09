#!/usr/bin/env python3
"""Snapshot and verify native products exhaustively in XSIM; module evidence only."""
import argparse,hashlib,json,shutil,subprocess,time
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
BIN=Path('/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin')
def main():
 p=argparse.ArgumentParser();p.add_argument('work',type=Path);a=p.parse_args();out=a.work.resolve();out.mkdir(parents=True,exist_ok=False);src=out/'source';src.mkdir()
 files=[BASE/'rtl/qwen_fp32_pkg.sv',BASE/'rtl/qwen_bf16_product_pipe.sv',BASE/'tb/tb_qwen_bf16_product.sv']
 for f in files:shutil.copyfile(f,src/f.name)
 (out/'manifest.json').write_text(json.dumps({'scope':'Native product exhaustive/edge and protocol checks against scalar FP32 reference; no board proof.','source_sha256':{str(f.relative_to(BASE)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}},indent=2)+'\n')
 commands=[([str(BIN/'xvlog'),'--sv']+[str(src/f.name) for f in files],'compile.log'),([str(BIN/'xelab'),'tb_qwen_bf16_product','-s','native_product','--debug','typical','--timescale','1ns/1ps'],'elaborate.log'),([str(BIN/'xsim'),'native_product','-runall'],'simulation.log')]
 started=time.monotonic();rc=0
 for cmd,name in commands:
  with (out/name).open('w') as f:rc=subprocess.run(cmd,cwd=out,stdout=f,stderr=subprocess.STDOUT).returncode
  if rc:break
 text=(out/'simulation.log').read_text() if (out/'simulation.log').exists() else ''
 passed=rc==0 and 'PASS native BF16 product payload/error/ID/backpressure/reset' in text and 'Fatal:' not in text
 (out/'result.json').write_text(json.dumps({'status':'passed_module_simulation' if passed else 'failed','seconds':time.monotonic()-started,'returncode':rc},indent=2)+'\n');print(text[-2000:]);raise SystemExit(0 if passed else 1)
if __name__=='__main__':main()
