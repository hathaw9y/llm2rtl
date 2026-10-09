#!/usr/bin/env python3
"""Build an A53 diagnostic ELF for the existing first-layer BIT/XSA."""
from pathlib import Path
import hashlib
import subprocess
import sys

design = Path(__file__).resolve().parents[1]
probe = design / "first_layer_no_kv_board_probe"
dest = probe / "artifacts"
stem = "zcu104_first_layer_no_kv_board_probe"
quality = "--quality" in sys.argv
bit = dest / f"{stem}.bit"
for path in (bit, probe / "diagnostic_vectors.h"):
    if not path.is_file():
        raise FileNotFoundError(path)
old = design / "build/gemm_board_vitis_cli"
bsp = old / "zcu104_gemm_platform/export/zcu104_gemm_platform/sw/standalone_a53_0"
linker = old / "gemm_board_smoke/src/lscript.ld"
compiler = Path("/media/admin1/backup/tools/Xilinx/2025.2/Vitis/gnu/aarch64/lin/aarch64-none/bin/aarch64-none-elf-gcc")
suffix = "quality" if quality else "diagnostic"
elf = dest / f"{stem}_{suffix}.elf"
defines = ["-DFIRST_LAYER_DIAGNOSTIC"]
if quality:
    defines.append("-DFIRST_LAYER_OUTPUT_DUMP")
subprocess.run([
    str(compiler), "-DSDT", *defines,
    f"-specs={bsp / 'Xilinx.spec'}", f"-I{bsp / 'include'}",
    "-Wall", "-Wextra", "-O0", "-g3", "-U__clang__",
    str(probe / "main.c"), "-o", str(elf), f"-Wl,-T,{linker}",
    f"-L{bsp / 'lib'}", "-Wl,--start-group", "-lxilstandalone",
    "-lxiltimer", "-lxil", "-lgcc", "-lc", "-Wl,--end-group",
], check=True)
runner = dest / f"run_{suffix}_on_zcu104.tcl"
runner.write_text((dest / "run_on_zcu104.tcl").read_text().replace(
    f"{stem}.elf", elf.name))
(dest / f"{suffix.upper()}_SHA256SUMS").write_text("".join(
    f"{hashlib.sha256((dest / name).read_bytes()).hexdigest()}  {name}\n"
    for name in (f"{stem}.bit", elf.name, runner.name, "psu_init.tcl")))
print(elf)
