#!/usr/bin/env python3
"""Fresh XSIM native integration; vendor DMA is not included in this packet test."""
import os,json,hashlib,shutil,subprocess,argparse
from pathlib import Path
BASE=Path(__file__).resolve().parents[1];ROOT=BASE.parents[1];BIN=Path('/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin')
def main():
 p=argparse.ArgumentParser();p.add_argument('work',type=Path);p.add_argument('--dma',action='store_true');p.add_argument('--board',action='store_true');p.add_argument('--physical-banks',action='store_true');a=p.parse_args();a.dma=a.dma or a.board;a.physical_banks=a.physical_banks or a.board;work=a.work.resolve();work.mkdir(exist_ok=False,parents=True);(work/'source').mkdir();(work/'designs').symlink_to(ROOT/'designs',target_is_directory=True)
 names=['qwen_fp32_pkg','qwen_fp32_pipe','qwen_bf16_product_pipe','qwen_nonlinear_scalar','qwen_reduce16_scalar','qwen_dot16x4','qwen_gemm_executor','qwen_rmsnorm_executor','qwen_rope_executor','qwen_softmax_executor','qwen_vector_executor','qwen_dispatcher','qwen_bank_descriptors','qwen_bank_fabric','qwen_core']
 tb='tb_qwen_board_shell' if a.board else ('tb_qwen_dma_core' if a.dma else 'tb_qwen_core')
 if a.dma:names.append('qwen_dma_core')
 if a.board:names+=['qwen_control_regs','qwen_board_shell']
 files=[BASE/'rtl'/(f+'.sv') for f in names]+[ROOT/'ip/infrastructure/bank_ownership_table/rtl/bank_ownership_table.sv',BASE/'tb'/(tb+'.sv')]
 common=ROOT/'ip/infrastructure/datamover_engine/rtl'
 if a.dma:
  common_names=['datamover_engine_pkg','datamover_command_queue','fifo','pipeline','status_decoder','axis_width_up_converter','axis_width_down_converter','axis_width_converter','mm2s_channel','s2mm_channel','datamover_engine','mm2s_adapter','s2mm_adapter']
  files=[common/(n+'.sv') for n in common_names]+files
 if a.physical_banks:files=[common/'bram_bank.sv',common/'uram_bank.sv']+files
 for f in files:shutil.copyfile(f,work/'source'/f.name)
 inputs=files+list((BASE/'evidence/core_packet_run002').glob('*'))+list((BASE/'evidence/fp32_run001').glob('*.mem'))
 (work/'manifest.json').write_text(json.dumps({'scope':{'DMA':'Common engine/adapters and vendor DataMover stream model' if a.dma else 'Native DMA model','banks':'Actual common XPM BRAM/URAM wrappers' if a.physical_banks else 'Logical native bank model','limits':'Bounded packets; no full-model RTL or physical DDR/board proof.'},'source_and_vector_sha256':{str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs if f.is_file()}},indent=2)+'\n')
 def run(cmd,name):
  with (work/name).open('w') as log:r=subprocess.run(cmd,cwd=work,stdout=log,stderr=subprocess.STDOUT)
  if r.returncode:raise RuntimeError(name+' failed')
 run([str(BIN/'xvlog'),'--sv']+([] if a.physical_banks else ['-d','QWEN_BANK_SIMULATION'])+[str(work/'source'/f.name) for f in files],'xvlog.log')
 run([str(BIN/'xelab'),tb,'-L','xpm','-s','qwen_core_packet','--debug','typical','--timescale','1ns/1ps'],'xelab.log')
 run([str(BIN/'xsim'),'qwen_core_packet','-runall'],'simulation.log')
 text=(work/'simulation.log').read_text()
 passed=('PASS board shell:' if a.board else ('PASS DMA core: common engine' if a.dma else 'PASS core all compute opcodes')) in text and 'FATAL' not in text
 (work/'result.json').write_text(json.dumps({'status':'passed_bounded_integration' if passed else 'failed','returncode':0,'manifest_sha256':hashlib.sha256((work/'manifest.json').read_bytes()).hexdigest()},indent=2)+'\n');print(text[-3000:],flush=True)
 if not passed:raise SystemExit(1)
if __name__=='__main__':main()
