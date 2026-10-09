#!/usr/bin/env python3
"""Build the DDR probe against the previously generated ZCU104 A53 BSP.

This is a fallback for an unresponsive Vitis platform generator. The new
bitstream, HWH, and PS initialization always come from the new XSA.
"""
from pathlib import Path
import hashlib
import subprocess
import zipfile

design = Path(__file__).resolve().parents[1]
old = design / "build/gemm_board_vitis_cli"
bsp = old / "zcu104_gemm_platform/export/zcu104_gemm_platform/sw/standalone_a53_0"
linker = old / "gemm_board_smoke/src/lscript.ld"
compiler = Path("/media/admin1/backup/tools/Xilinx/2025.2/Vitis/gnu/aarch64/lin/aarch64-none/bin/aarch64-none-elf-gcc")
artifacts = design / "dma_rms_gemm_rope_attention_add_board_probe/artifacts"
xsa = artifacts / "zcu104_dma_rms_gemm_rope_attention_add_board_probe.xsa"
elf = artifacts / "zcu104_dma_rms_gemm_rope_attention_add_board_probe.elf"
for path in (compiler, bsp / "Xilinx.spec", bsp / "lib/libxil.a", linker, xsa):
    if not path.is_file():
        raise FileNotFoundError(path)

subprocess.run([
    str(compiler), "-DSDT", f"-specs={bsp / 'Xilinx.spec'}",
    f"-I{bsp / 'include'}", "-Wall", "-Wextra", "-O0", "-g3",
    "-U__clang__", str(design / "dma_rms_gemm_rope_attention_add_board_probe/main.c"),
    "-o", str(elf), f"-Wl,-T,{linker}", f"-L{bsp / 'lib'}",
    "-Wl,--start-group", "-lxilstandalone", "-lxiltimer", "-lxil",
    "-lgcc", "-lc", "-Wl,--end-group"
], check=True)
with zipfile.ZipFile(xsa) as archive:
    (artifacts / "zcu104_dma_rms_gemm_rope_attention_add_board_probe.hwh").write_bytes(
        archive.read("system.hwh"))
    (artifacts / "psu_init.tcl").write_bytes(archive.read("psu_init.tcl"))
names = [f"zcu104_dma_rms_gemm_rope_attention_add_board_probe.{ext}"
         for ext in ("bit", "xsa", "hwh", "elf")]
names += ["psu_init.tcl", "run_on_zcu104.tcl"]
(artifacts / "SHA256SUMS").write_text("".join(
    f"{hashlib.sha256((artifacts / name).read_bytes()).hexdigest()}  {name}\n"
    for name in names))
print(f"DMA_BOARD_APP_EXISTING_BSP {elf}")
