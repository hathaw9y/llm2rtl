import subprocess
from pathlib import Path
p=Path('/tmp/qwen_bf16_product_xsim_run002');bin=Path('/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin')
commands=[([str(bin/'xvlog'),'--sv']+[str(p/'source'/n) for n in ['qwen_fp32_pkg.sv','qwen_bf16_product_pipe.sv','tb_qwen_bf16_product.sv']],'compile.log'),([str(bin/'xelab'),'tb_qwen_bf16_product','-s','native_product','--debug','typical','--timescale','1ns/1ps'],'elaborate.log'),([str(bin/'xsim'),'native_product','-runall'],'simulation.log')]
for c,n in commands:
 with (p/n).open('w') as f:subprocess.run(c,cwd=p,stdout=f,stderr=subprocess.STDOUT,check=True)
s=(p/'simulation.log').read_text();assert 'PASS native BF16 product payload/error/ID/backpressure/reset' in s and 'Fatal:' not in s;print(s[-1800:])
