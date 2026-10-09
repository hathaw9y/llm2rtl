#!/usr/bin/env python3
"""Compile actual o_proj board app against the previously routed ADD XSA."""
import hashlib
import json
import subprocess
import zipfile
from pathlib import Path

design = Path(__file__).resolve().parents[1]
base = design / "dma_rms_gemm_rope_attention_add_board_probe/artifacts"
base_record = json.loads((base / "verification.json").read_text())
dest = design / "first_layer_attention_output_board_probe/artifacts"
dest.mkdir(exist_ok=True)
stem = "zcu104_dma_rms_gemm_rope_attention_add_board_probe"
for name in (f"{stem}.bit", f"{stem}.xsa"):
    data = (base / name).read_bytes()
    assert hashlib.sha256(data).hexdigest() == base_record["artifact_sha256"][name]
    (dest / name).write_bytes(data)
with zipfile.ZipFile(dest / f"{stem}.xsa") as xsa:
    assert xsa.read(f"{stem}.bit") == (dest / f"{stem}.bit").read_bytes()
    (dest / f"{stem}.hwh").write_bytes(xsa.read("system.hwh"))
    (dest / "psu_init.tcl").write_bytes(xsa.read("psu_init.tcl"))

old = design / "build/gemm_board_vitis_cli"
bsp = old / "zcu104_gemm_platform/export/zcu104_gemm_platform/sw/standalone_a53_0"
linker = old / "gemm_board_smoke/src/lscript.ld"
compiler = Path("/media/admin1/backup/tools/Xilinx/2025.2/Vitis/gnu/aarch64/lin/aarch64-none/bin/aarch64-none-elf-gcc")
for path in (compiler, bsp / "Xilinx.spec", bsp / "lib/libxil.a", linker):
    if not path.is_file():
        raise FileNotFoundError(path)
elf_name = "zcu104_first_layer_attention_output_probe.elf"
subprocess.run([
    str(compiler), "-DSDT", f"-specs={bsp / 'Xilinx.spec'}",
    f"-I{bsp / 'include'}", "-Wall", "-Wextra", "-O0", "-g3", "-U__clang__",
    str(design / "first_layer_attention_output_board_probe/main.c"),
    "-o", str(dest / elf_name), f"-Wl,-T,{linker}", f"-L{bsp / 'lib'}",
    "-Wl,--start-group", "-lxilstandalone", "-lxiltimer", "-lxil",
    "-lgcc", "-lc", "-Wl,--end-group",
], check=True)
names = [f"{stem}.{ext}" for ext in ("bit", "xsa", "hwh")]
names += [elf_name, "psu_init.tcl", "run_on_zcu104.tcl"]
(dest / "SHA256SUMS").write_text("".join(
    f"{hashlib.sha256((dest / name).read_bytes()).hexdigest()}  {name}\n"
    for name in names))
print(dest / elf_name)
