#!/usr/bin/env python3
"""Build interactive SmolLM2 A53 app and host tokenizer handoff."""
from pathlib import Path
import hashlib
import os
import shutil
import subprocess
import tarfile

D = Path(__file__).resolve().parents[1]
P = D / 'full_model_board_probe'
I = D / 'interactive_board_probe'
A = I / 'artifacts'
A.mkdir(parents=True, exist_ok=True)
old = D / 'build/gemm_board_vitis_cli'
bsp = old / 'zcu104_gemm_platform/export/zcu104_gemm_platform/sw/standalone_a53_0'
fsbl_headers = old / 'zcu104_gemm_platform/zynqmp_fsbl/zynqmp_fsbl_bsp/include'
linker = old / 'gemm_board_smoke/src/lscript.ld'
vitis = Path('/media/admin1/backup/tools/Xilinx/2025.2/Vitis')
compiler = vitis / 'gnu/aarch64/lin/aarch64-none/bin/aarch64-none-elf-gcc'
ffs = vitis / 'data/embeddedsw/lib/sw_services/xilffs_v5_5/src'
checkpoint = Path('/home/shmin/.cache/huggingface/hub/models--HuggingFaceTB--SmolLM2-135M/snapshots/93efa2f097d58c2a74874c7e644dbc9b0cee75a2')
elf = A / 'smollm2_interactive_sd.elf'
subprocess.run([str(compiler), '-DSDT',
    f'-specs={bsp / "Xilinx.spec"}', f'-I{ffs / "include"}',
    f'-I{fsbl_headers}', f'-I{bsp / "include"}', f'-I{P}',
    '-Wall', '-Wextra', '-Werror', '-Wno-error=unused-variable',
    '-O0', '-g3', '-U__clang__',
    str(P / 'interactive_main.c'), str(P / 'program.c'),
    str(P / 'sd_model_loader.c'), str(ffs / 'ff.c'),
    str(ffs / 'diskio.c'), str(ffs / 'ffsystem.c'),
    '-o', str(elf), f'-Wl,-T,{linker}', f'-L{bsp / "lib"}',
    '-Wl,--start-group', '-lxilstandalone', '-lxiltimer', '-lxil',
    '-lgcc', '-lc', '-Wl,--end-group'], check=True)

(A / 'run_on_zcu104_interactive.tcl').write_text('''# Run from existing full_model_board_probe/artifacts/interactive.
set interactive_dir [file dirname [file normalize [info script]]]
set artifact_dir [file dirname $interactive_dir]
set bit_file [file join $artifact_dir zcu104_first_layer_kv_board_probe.bit]
set ps_init_file [file join $artifact_dir psu_init.tcl]
set elf_file [file join $interactive_dir smollm2_interactive_sd.elf]
foreach path [list $bit_file $ps_init_file $elf_file] {
    if {![file isfile $path]} {error "Missing artifact: $path"}
}
connect
targets -set -filter {name =~ "Cortex-A53 #0"}
catch {stop}
rst -processor
targets -set -filter {name =~ "PSU"}
fpga $bit_file
source $ps_init_file
psu_init
after 1000
psu_ps_pl_isolation_removal
after 1000
psu_ps_pl_reset_config
targets -set -filter {name =~ "Cortex-A53 #0"}
rst -processor
dow $elf_file
puts "Starting SmolLM2 interactive app. Connect host ask.py to PS UART 115200."
con
after 10000
''')

tokenizer_dir = A / 'tokenizer'
tokenizer_dir.mkdir(exist_ok=True)
tokenizer_names = ('tokenizer.json', 'tokenizer_config.json',
                   'special_tokens_map.json', 'vocab.json', 'merges.txt')
for name in tokenizer_names:
    shutil.copyfile(checkpoint / name, tokenizer_dir / name)
shutil.copy2(I / 'ask.py', A / 'ask.py')
files = [elf, A / 'run_on_zcu104_interactive.tcl', A / 'ask.py']
files += [tokenizer_dir / name for name in tokenizer_names]
shutil.copy2(I / 'README.md', A / 'README.md')
shutil.copy2(I / 'program_verification.json', A / 'program_verification.json')
files += [A / 'README.md', A / 'program_verification.json']
(A / 'SHA256SUMS').write_text(''.join(
    f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {os.path.relpath(path,A)}\n'
    for path in files))
archive = D / 'interactive_board_handoff.tar.gz'
with tarfile.open(archive, 'w:gz', compresslevel=6) as tar:
    for path in files + [A / 'SHA256SUMS']:
        tar.add(path, arcname='interactive/' + str(path.relative_to(A)))
print(elf)
print(archive)
print(hashlib.sha256(archive.read_bytes()).hexdigest())
