#!/usr/bin/env python3
"""Actual AMD proc_sys_reset polarity and control AXI test, no FPGA proof."""
import argparse,hashlib,json,shutil,subprocess
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
BIN=Path('/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin')
def main():
 p=argparse.ArgumentParser();p.add_argument('out',type=Path);a=p.parse_args();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 files=[BASE/'tb/tb_qwen_board_reset.sv',BASE/'rtl/qwen_control_regs.sv']
 wrapper=BASE/'tb/qwen_vendor_reset_test_wrapper.vhd'
 shutil.copyfile(wrapper,out/wrapper.name)
 for f in files:shutil.copyfile(f,out/f.name)
 def run(command,name):
  with (out/name).open('w') as log:subprocess.run(command,cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
 run([str(BIN/'xvlog'),'--sv']+[f.name for f in files]+[str(BIN.parent/'data/verilog/src/glbl.v')],'xvlog.log')
 run([str(BIN/'xvhdl'),wrapper.name],'xvhdl.log')
 run([str(BIN/'xelab'),'tb_qwen_board_reset','glbl','-L','proc_sys_reset_v5_0_17','-L','unisims_ver','-L','unisim','-s','board_reset','--debug','typical','-mt','2'],'xelab.log')
 (out/'run.tcl').write_text('run all\nquit\n')
 run([str(BIN/'xsim'),'board_reset','-tclbatch','run.tcl'],'simulation.log')
 text=(out/'simulation.log').read_text();passed='PASS_ACTUAL_VENDOR_BOARD_RESET_200MHZ_OLD_FAILURE_FIXED_RELEASE_PROFILE_REASSERT' in text and 'Fatal' not in text
 vendor=Path('/media/admin1/backup/tools/Xilinx/2025.2/data/ip/xilinx/proc_sys_reset_v5_0/hdl/proc_sys_reset_v5_0_vh_rfs.vhd')
 report={'status':'passed_actual_vendor_reset_plus_control_AXI' if passed else 'failed','clock_ns':5,'scope':'Actual proc_sys_reset model + existing control regs; excludes complete SmartConnect/PS/DDR and physical board','source_sha256':{str(f):hashlib.sha256(f.read_bytes()).hexdigest() for f in files+[wrapper,vendor]}}
 (out/'result.json').write_text(json.dumps(report,indent=2)+'\n');print(text[-1600:])
 if not passed:raise SystemExit(1)
if __name__=='__main__':main()
