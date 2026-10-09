#!/usr/bin/env python3
"""Build the full-output A53 probe against its matching routed BIT/XSA."""
from pathlib import Path
import hashlib
import subprocess
import zipfile

design = Path(__file__).resolve().parents[1]
probe = design / "first_layer_no_kv_board_probe"
dest = design / "first_layer_full_output_board_probe/artifacts"
stem = "zcu104_first_layer_full_output_board_probe"
bit = dest / f"{stem}.bit"
xsa_path = dest / f"{stem}.xsa"
for path in (bit, xsa_path, probe / "vectors.h",
             probe / "diagnostic_vectors.h",
             dest.parent / "full_output_vectors.h"):
    if not path.is_file():
        raise FileNotFoundError(path)
with zipfile.ZipFile(xsa_path) as xsa:
    assert xsa.read(f"{stem}.bit") == bit.read_bytes()
    (dest / f"{stem}.hwh").write_bytes(xsa.read("system.hwh"))
    (dest / "psu_init.tcl").write_bytes(xsa.read("psu_init.tcl"))

old = design / "build/gemm_board_vitis_cli"
bsp = old / "zcu104_gemm_platform/export/zcu104_gemm_platform/sw/standalone_a53_0"
linker = old / "gemm_board_smoke/src/lscript.ld"
compiler = Path("/media/admin1/backup/tools/Xilinx/2025.2/Vitis/gnu/aarch64/lin/aarch64-none/bin/aarch64-none-elf-gcc")
elf = dest / f"{stem}.elf"
subprocess.run([
    str(compiler), "-DSDT", "-DFIRST_LAYER_DIAGNOSTIC",
    "-DFIRST_LAYER_FULL_OUTPUT", f"-specs={bsp / 'Xilinx.spec'}",
    f"-I{bsp / 'include'}", "-Wall", "-Wextra", "-O0", "-g3", "-U__clang__",
    str(probe / "main.c"), "-o", str(elf), f"-Wl,-T,{linker}",
    f"-L{bsp / 'lib'}", "-Wl,--start-group", "-lxilstandalone",
    "-lxiltimer", "-lxil", "-lgcc", "-lc", "-Wl,--end-group",
], check=True)
(dest / "run_on_zcu104.tcl").write_text(f'''# Run on the host PC with: xsct run_on_zcu104.tcl
set artifact_dir [file dirname [file normalize [info script]]]
set bit_file [file join $artifact_dir {stem}.bit]
set elf_file [file join $artifact_dir {stem}.elf]
set ps_init_file [file join $artifact_dir psu_init.tcl]
foreach path [list $bit_file $elf_file $ps_init_file] {{
    if {{![file isfile $path]}} {{ error "Missing artifact: $path" }}
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
dow $elf_file
puts "Starting A53-0. Capture psu_uart_0 at 115200 8-N-1."
con
after 10000
''')
names = [f"{stem}.{ext}" for ext in ("bit", "xsa", "hwh", "elf")]
names += ["psu_init.tcl", "run_on_zcu104.tcl"]
(dest / "SHA256SUMS").write_text("".join(
    f"{hashlib.sha256((dest / name).read_bytes()).hexdigest()}  {name}\n"
    for name in names))
print(elf)
