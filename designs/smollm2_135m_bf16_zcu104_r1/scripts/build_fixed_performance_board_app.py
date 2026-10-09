#!/usr/bin/env python3
"""Build a fixed prefill32/decode1 timing ELF for the existing 100 MHz BIT."""
from pathlib import Path
import hashlib
import shutil
import subprocess
import tarfile

D = Path(__file__).resolve().parents[1]
P = D / "full_model_board_probe"
A = D / "fixed_performance_board_probe" / "artifacts"
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

elf = A / "smollm2_fixed_perf_sd.elf"
command = [str(compiler), "-DSDT", "-DLOAD_MODEL_FROM_SD", "-DPERF_ONLY",
           f"-specs={bsp / 'Xilinx.spec'}", f"-I{ffs / 'include'}",
           f"-I{fsbl_headers}", f"-I{bsp / 'include'}",
           "-Wall", "-Wextra", "-O0", "-g3", "-U__clang__",
           str(P / "main.c"), str(P / "program.c"), str(P / "sd_model_loader.c"),
           str(ffs / "ff.c"), str(ffs / "diskio.c"), str(ffs / "ffsystem.c"),
           "-o", str(elf), f"-Wl,-T,{linker}", f"-L{bsp / 'lib'}",
           "-Wl,--start-group", "-lxilstandalone", "-lxiltimer", "-lxil",
           "-lgcc", "-lc", "-Wl,--end-group"]
subprocess.run(command, check=True)

run = A / "run_fixed_perf_sd.tcl"
run.write_text('''# Run from the directory containing the existing 100 MHz BIT and psu_init.tcl.
set artifact_dir [file dirname [file normalize [info script]]]
set bit_file [file join $artifact_dir zcu104_first_layer_kv_board_probe.bit]
set elf_file [file join $artifact_dir smollm2_fixed_perf_sd.elf]
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
puts "Starting fixed performance probe. Capture UART at 115200."
con
after 10000
''')
readme = A / "README_FIXED_PERF.md"
readme.write_text('''# Fixed SmolLM2 power and throughput evaluation

This ELF uses the existing 100 MHz BIT and the same SD `MODEL.BIN` as the
numeric 30-layer probe. It runs fixed prefill32 followed by decode1. It emits
`PERF_BLOCK` records with A53 timer microseconds. The timed scope includes ISA
issue, DMA, PL execution and completion polling. It excludes SD loading,
per-layer golden comparisons and final UART reporting. Each layer still checks
the ADD write count. The existing numeric ELF remains the correctness evidence.

Copy `smollm2_fixed_perf_sd.elf` and `run_fixed_perf_sd.tcl` next to
`zcu104_first_layer_kv_board_probe.bit` and `psu_init.tcl`. With `MODEL.BIN`
on the SD card, capture UART and run:

```
xsct -nodisp run_fixed_perf_sd.tcl
```

The UART must contain exactly one `PERF_BLOCK prefill32 0 32 ...` and one
`PERF_BLOCK decode1 32 33 ...` followed by
`BOARD FIXED PERFORMANCE ISA EXECUTION COMPLETE`. Measure
average input power separately over each block if reporting board TOPS/W.
After capturing UART as `uart_perf.txt`, calculate time and nominal operation
throughput with:

```
python3 evaluate_energy_efficiency.py --log uart_perf.txt
```

For measured efficiency, record mean board input power separately during the
`PERF_BEGIN` to `PERF_BLOCK` intervals and add, for example:

```
python3 evaluate_energy_efficiency.py --log uart_perf.txt \\
  --prefill-power-w 4.2 --decode-power-w 3.8 \\
  --power-source measured --power-scope board_input \\
  --json-out energy_result.json
```

The W values above are examples, not measurements. Use your measured values.
The script reports nominal GEMM+attention TOPS/W and tokens/J. The operation
count is checked against the fixed ISA traces. The time excludes model SD
loading and UART output. If power comes from Vivado instead of a meter, select
`--power-source vivado_estimate --power-scope on_chip_estimate`; the output
will be labeled estimated efficiency.

The 100 MHz BIT is reused; this package changes only the A53 ELF and runner.
''')
evaluator = A / "evaluate_energy_efficiency.py"
shutil.copyfile(D / "scripts/evaluate_energy_efficiency.py", evaluator)
files = [elf, run, readme, evaluator]
checksums = A / "SHA256SUMS_FIXED_PERF"
checksums.write_text("".join(
    f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n"
    for path in files))
archive = D / "fixed_performance_board_handoff.tar.gz"
with tarfile.open(archive, "w:gz", compresslevel=6) as tar:
    for path in files + [checksums]:
        tar.add(path, arcname=path.name)
print(elf)
print(archive)
print(hashlib.sha256(archive.read_bytes()).hexdigest())
