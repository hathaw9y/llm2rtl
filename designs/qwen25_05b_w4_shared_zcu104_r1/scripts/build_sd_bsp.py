#!/usr/bin/env python3
"""Generate read-only SD/FAT BSP from the exact routed XSA; no board access."""
import argparse,hashlib,json,os,shutil,subprocess
from pathlib import Path
TOOLS=Path('/media/admin1/backup/tools/Xilinx/2025.2')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('xsa',type=Path);p.add_argument('out',type=Path);a=p.parse_args()
 out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
 shutil.copyfile(a.xsa,out/'qwen.xsa')
 script=out/'generate.tcl'
 script.write_text('''set qwen_sd_out [file dirname [file normalize [info script]]]
hsi::open_hw_design [file join $qwen_sd_out qwen.xsa]
set sd [hsi::get_cells -filter {IP_NAME == psu_sd}]
if {[llength $sd]!=1 || [common::get_property CONFIG.C_S_AXI_BASEADDR $sd] ne "0xFF170000"} {error "Expected only SD1 at FF170000"}
hsi::create_sw_design qwen_sd_bsp -proc psu_cortexa53_0 -os standalone
hsi::add_library xilffs
common::set_property CONFIG.read_only true [hsi::get_libs xilffs]
common::set_property CONFIG.use_mkfs false [hsi::get_libs xilffs]
common::set_property CONFIG.use_lfn 0 [hsi::get_libs xilffs]
common::set_property CONFIG.num_logical_vol 1 [hsi::get_libs xilffs]
common::set_property CONFIG.enable_exfat false [hsi::get_libs xilffs]
hsi::generate_bsp -dir [file join $qwen_sd_out bsp]
puts "PASS_GENERATED_READONLY_SD1_BSP"
exit
''')
 with (out/'generate.log').open('w') as log:subprocess.run([str(TOOLS/'Vitis/bin/xsct'),'-nodisp',str(script)],cwd=out,stdout=log,stderr=subprocess.STDOUT,check=True)
 bsp=out/'bsp';makefile=bsp/'Makefile';makefile.write_text(makefile.read_text().replace('-j 30','-j 2'))
 # The custom startup leaves FP/SIMD disabled. Compile the linked filesystem,
 # SD driver and standalone C helpers using integer general registers only.
 for component in ['standalone_v9_4','sdps_v4_5','xilffs_v5_5']:
  mf=bsp/'psu_cortexa53_0/libsrc'/component/'src/Makefile'
  flags='-ffunction-sections -fdata-sections -fno-tree-vectorize -fno-tree-slp-vectorize'
  if component!='standalone_v9_4':flags+=' -mgeneral-regs-only'
  with mf.open('a') as f:f.write('\noverride EXTRA_COMPILER_FLAGS += '+flags+'\n')
 env=dict(os.environ);env['PATH']=str(TOOLS/'gnu/aarch64/lin/aarch64-none/bin')+os.pathsep+env['PATH']
 with (out/'build.log').open('w') as log:subprocess.run(['make'],cwd=bsp,env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
 proc=bsp/'psu_cortexa53_0'
 parameters=(proc/'include/xparameters.h').read_text()
 if '#define FILE_SYSTEM_READ_ONLY' not in parameters or '#define FILE_SYSTEM_USE_MKFS' in parameters:raise ValueError('Unsafe filesystem configuration')
 manifest={'status':'compiled_readonly_SD1_BSP_no_board_test','XSA_sha256':sha(out/'qwen.xsa'),'xparameters_sha256':sha(proc/'include/xparameters.h'),'libxil_sha256':sha(proc/'lib/libxil.a'),'xilffs':'5.5','SD_controller':'SD1 FF170000, logical drive0','filesystem':'FAT read-only, no mkfs, short QWEN.BIN filename','generation_and_build':'AMD2025.2 local embeddedsw, build jobs2'}
 manifest['libxilffs_sha256']=sha(proc/'lib/libxilffs.a')
 (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(manifest,indent=2))
if __name__=='__main__':main()
