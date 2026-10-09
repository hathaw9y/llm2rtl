#!/usr/bin/env python3
"""Build matched full-model A53 app using the routed 100 MHz KV board image."""
from pathlib import Path
import hashlib
import os
import shutil
import subprocess
import zipfile
D=Path(__file__).resolve().parents[1]
P=D/'full_model_board_probe'
A=P/'artifacts'
A.mkdir(exist_ok=True)
source=D/'first_layer_kv_board_probe/artifacts'
stem='zcu104_first_layer_kv_board_probe'
for name in (f'{stem}.bit',f'{stem}.xsa',f'{stem}.hwh','psu_init.tcl',
             'routed_timing_summary.rpt','routed_utilization.rpt','routed_drc.rpt'):
    shutil.copy2(source/name,A/name)
with zipfile.ZipFile(A/f'{stem}.xsa') as z:
    assert z.read(f'{stem}.bit')==(A/f'{stem}.bit').read_bytes()
    assert z.read('system.hwh')==(A/f'{stem}.hwh').read_bytes()
old=D/'build/gemm_board_vitis_cli'
bsp=old/'zcu104_gemm_platform/export/zcu104_gemm_platform/sw/standalone_a53_0'
linker=old/'gemm_board_smoke/src/lscript.ld'
compiler=Path('/media/admin1/backup/tools/Xilinx/2025.2/Vitis/gnu/aarch64/lin/aarch64-none/bin/aarch64-none-elf-gcc')
elf=A/'smollm2_full_model_30_layer_probe.elf'
subprocess.run([str(compiler),'-DSDT',f'-specs={bsp/"Xilinx.spec"}',
    f'-I{bsp/"include"}','-Wall','-Wextra','-Werror','-O0','-g3','-U__clang__',
    str(P/'main.c'),str(P/'program.c'),'-o',str(elf),f'-Wl,-T,{linker}',
    f'-L{bsp/"lib"}','-Wl,--start-group','-lxilstandalone','-lxiltimer',
    '-lxil','-lgcc','-lc','-Wl,--end-group'],check=True)
(A/'run_on_zcu104.tcl').write_text(f'''# Run from this artifacts directory: xsct -nodisp run_on_zcu104.tcl
set artifact_dir [file dirname [file normalize [info script]]]
set bit_file [file join $artifact_dir {stem}.bit]
set elf_file [file join $artifact_dir smollm2_full_model_30_layer_probe.elf]
set ps_init_file [file join $artifact_dir psu_init.tcl]
set ddr_file [file join $artifact_dir .. ddr_static_bf16.bin]
foreach path [list $bit_file $elf_file $ps_init_file $ddr_file] {{
    if {{![file isfile $path]}} {{error "Missing artifact: $path"}}
}}
connect
targets -set -filter {{name =~ "PSU"}}
fpga $bit_file
source $ps_init_file
psu_init
after 1000
psu_ps_pl_isolation_removal
after 1000
psu_ps_pl_reset_config
targets -set -filter {{name =~ "Cortex-A53 #0"}}
rst -processor
puts "Loading 269161088 static BF16 bytes to DDR at 0x57A00000..."
dow -data $ddr_file 0x57A00000
puts "Static DDR load finished. Downloading ISA control app..."
dow $elf_file
puts "Starting A53-0; capture psu_uart_0 at 115200 8-N-1."
con
after 10000
''')
files=[A/f'{stem}.{ext}' for ext in ('bit','xsa','hwh')]
files += [A/'smollm2_full_model_30_layer_probe.elf',A/'psu_init.tcl',
          A/'run_on_zcu104.tcl',A/'verification.json',
          P/'ddr_static_bf16.bin',P/'golden.h',
          P/'address_map.h',P/'manifest.json',P/'program_verification.json',
          P/'README.md',P/'main.c',P/'program.c',P/'program.h',
          P/'program_trace.c',P/'trace_prefill.hex',P/'trace_decode.hex',
          A/'routed_timing_summary.rpt',A/'routed_utilization.rpt',A/'routed_drc.rpt']
(A/'SHA256SUMS').write_text(''.join(
    f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {os.path.relpath(path,A)}\n'
    for path in files))
print(elf)
