#!/usr/bin/env python3
"""Build matched numeric and timing apps for the GEMM_TILES bitstream."""
from pathlib import Path
import subprocess

D = Path(__file__).resolve().parents[1]
P = D / "full_model_board_probe"
A = D / "perf128_board_probe" / "artifacts"
A.mkdir(parents=True, exist_ok=True)
old = D / "build/gemm_board_vitis_cli"
bsp = old / "zcu104_gemm_platform/export/zcu104_gemm_platform/sw/standalone_a53_0"
fsbl_headers = old / "zcu104_gemm_platform/zynqmp_fsbl/zynqmp_fsbl_bsp/include"
linker = old / "gemm_board_smoke/src/lscript.ld"
vitis = Path("/media/admin1/backup/tools/Xilinx/2025.2/Vitis")
compiler = vitis / "gnu/aarch64/lin/aarch64-none/bin/aarch64-none-elf-gcc"
ffs = vitis / "data/embeddedsw/lib/sw_services/xilffs_v5_5/src"
for path in (compiler, ffs / "ff.c", ffs / "diskio.c",
             fsbl_headers / "xilffs_config.h", bsp / "lib/libxil.a"):
    if not path.exists():
        raise FileNotFoundError(path)

for name, flags in (
    ("smollm2_perf128_sd.elf", ["-DPERF_ONLY", "-DPROFILE_PL"]),
):
    elf = A / name
    command = [str(compiler), "-DSDT", "-DLOAD_MODEL_FROM_SD",
               "-DUSE_GEMM_TILES", *flags, f"-specs={bsp / 'Xilinx.spec'}",
               f"-I{ffs / 'include'}", f"-I{fsbl_headers}",
               f"-I{bsp / 'include'}", "-Wall", "-Wextra", "-O0", "-g3",
               "-U__clang__", str(P / "main.c"), str(P / "program.c"),
               str(P / "sd_model_loader.c"), str(ffs / "ff.c"),
               str(ffs / "diskio.c"), str(ffs / "ffsystem.c"),
               "-o", str(elf), f"-Wl,-T,{linker}", f"-L{bsp / 'lib'}",
               "-Wl,--start-group", "-lxilstandalone", "-lxiltimer",
               "-lxil", "-lgcc", "-lc", "-Wl,--end-group"]
    subprocess.run(command, check=True)
    print(elf)

run = '''set artifact_dir [file dirname [file normalize [info script]]]
set bit_file [file join $artifact_dir zcu104_perf128_board_probe.bit]
set elf_file [file join $artifact_dir @ELF@]
set ps_init_file [file join $artifact_dir psu_init.tcl]
foreach path [list $bit_file $elf_file $ps_init_file] {
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
puts "Starting 128-bit PL profile probe; capture UART at 115200."
con
after 10000
'''
(A / "run_perf128.tcl").write_text(run.replace("@ELF@", "smollm2_perf128_sd.elf"))
