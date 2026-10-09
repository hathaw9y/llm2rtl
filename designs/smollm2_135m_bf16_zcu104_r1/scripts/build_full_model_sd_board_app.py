#!/usr/bin/env python3
"""Build SD-backed A53 app against installed Vitis 2025.2 xilffs sources."""
from pathlib import Path
import hashlib
import os
import subprocess
import tarfile

D = Path(__file__).resolve().parents[1]
P = D / 'full_model_board_probe'
A = D / 'full_model_sd_board_probe' / 'artifacts'
A.mkdir(parents=True, exist_ok=True)
old = D / 'build/gemm_board_vitis_cli'
bsp = old / 'zcu104_gemm_platform/export/zcu104_gemm_platform/sw/standalone_a53_0'
fsbl_headers = old / 'zcu104_gemm_platform/zynqmp_fsbl/zynqmp_fsbl_bsp/include'
linker = old / 'gemm_board_smoke/src/lscript.ld'
vitis = Path('/media/admin1/backup/tools/Xilinx/2025.2/Vitis')
compiler = vitis / 'gnu/aarch64/lin/aarch64-none/bin/aarch64-none-elf-gcc'
ffs = vitis / 'data/embeddedsw/lib/sw_services/xilffs_v5_5/src'
for path in (compiler, ffs / 'ff.c', ffs / 'diskio.c',
             fsbl_headers / 'xilffs_config.h', bsp / 'lib/libxil.a'):
    if not path.exists():
        raise FileNotFoundError(path)
elf = A / 'smollm2_full_model_30_layer_sd_probe.elf'
build_cmd = [str(compiler), '-DSDT', '-DLOAD_MODEL_FROM_SD',
    f'-specs={bsp / "Xilinx.spec"}', f'-I{ffs / "include"}',
    f'-I{fsbl_headers}', f'-I{bsp / "include"}',
    '-Wall', '-Wextra', '-O0', '-g3', '-U__clang__',
    str(P / 'main.c'), str(P / 'program.c'), str(P / 'sd_model_loader.c'),
    str(ffs / 'ff.c'), str(ffs / 'diskio.c'), str(ffs / 'ffsystem.c'),
    '-o', str(elf), f'-Wl,-T,{linker}', f'-L{bsp / "lib"}',
    '-Wl,--start-group', '-lxilstandalone', '-lxiltimer', '-lxil',
    '-lgcc', '-lc', '-Wl,--end-group']
subprocess.run(build_cmd, check=True)
diagnostic_elf = A / 'smollm2_full_model_lm_input_sd_probe.elf'
diagnostic_cmd = build_cmd.copy()
diagnostic_cmd.insert(3, '-DPROBE_LM_HEAD_INPUT')
diagnostic_cmd[diagnostic_cmd.index(str(elf))] = str(diagnostic_elf)
subprocess.run(diagnostic_cmd, check=True)
(A / 'run_on_zcu104_sd.tcl').write_text('''# Run from full_model_board_probe/artifacts after copying SD ELF here.
set artifact_dir [file dirname [file normalize [info script]]]
set bit_file [file join $artifact_dir zcu104_first_layer_kv_board_probe.bit]
set elf_file [file join $artifact_dir smollm2_full_model_30_layer_sd_probe.elf]
set ps_init_file [file join $artifact_dir psu_init.tcl]
foreach path [list $bit_file $elf_file $ps_init_file] {
    if {![file isfile $path]} {error "Missing artifact: $path"}
}
connect
# A prior probe may still be spinning in its final loop. Halt/reset it
# before changing the PL image or PS clocks.
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
puts "Starting A53-0; app reads 0:/MODEL.BIN into DDR. Capture UART at 115200."
con
after 10000
''')
(A / 'run_lm_head_input_sd.tcl').write_text(
    (A / 'run_on_zcu104_sd.tcl').read_text().replace(
        'smollm2_full_model_30_layer_sd_probe.elf',
        'smollm2_full_model_lm_input_sd_probe.elf'))
(A / 'README.md').write_text('''# SD-backed 30-layer board app

Place the verified 269,161,088-byte `MODEL.BIN` on the SD card FAT BOOT
partition before powering the board. Its SHA-256 must be
`7439dd37925be3ba6c3ef6853b1728d836c6bdda13d7bbbcc93f7966bd745c68`.
The app checks size and CRC32 `db7d52bb` while copying the image to DDR.
It then runs the same ISA prefill32 and decode1 test as the JTAG-loaded app.

Copy the ELF and Tcl into the existing `full_model_board_probe/artifacts`
directory, then run `xsct -nodisp run_on_zcu104_sd.tcl` there. The existing
100 MHz bitstream and psu_init.tcl are reused. No JTAG `dow -data` occurs.
The Tcl halts/resets an A53 app left running by a prior probe, so it can be
rerun with the board powered. Keep the SD card inserted and close any other
XSCT/Vitis JTAG session first.
`run_lm_head_input_sd.tcl` runs a diagnostic ELF that also reads the existing
RMSNorm tap for the first 16 BF16 channels per token. It reports the last
token's first 16 values entering lm_head for prefill and decode, compared
against the checkpoint. The 100 MHz bitstream does not expose the remaining
560 channels directly.
Physical SD load and 30-layer logits results are pending board execution.
''')
(A / 'lm_head_input_golden.h').write_bytes(
    (P / 'lm_head_input_golden.h').read_bytes())
files = [elf, diagnostic_elf, A / 'run_on_zcu104_sd.tcl',
         A / 'run_lm_head_input_sd.tcl', A / 'README.md',
         A / 'lm_head_input_golden.h']
(A / 'SHA256SUMS_SD').write_text(''.join(
    f'{hashlib.sha256(path.read_bytes()).hexdigest()}  '
    f'{os.path.relpath(path, A)}\n'
    for path in files))
archive = D / 'full_model_sd_update.tar.gz'
with tarfile.open(archive, 'w:gz', compresslevel=6) as tar:
    for path in files + [A / 'SHA256SUMS_SD']:
        tar.add(path, arcname=path.name)
print(elf)
print(archive)
print(hashlib.sha256(archive.read_bytes()).hexdigest())
