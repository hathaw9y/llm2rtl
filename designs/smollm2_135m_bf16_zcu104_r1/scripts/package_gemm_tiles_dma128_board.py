#!/usr/bin/env python3
"""Package the routed 128-bit DMA BIT/XSA with unchanged GEMM_TILES SD apps."""
from pathlib import Path
import hashlib
import json
import shutil
import tarfile
import zipfile

D = Path(__file__).resolve().parents[1]
A = D / "gemm_tiles_dma128_board_probe" / "artifacts"
project = D / "build/zcu104_gemm_tiles_dma128_board_probe_100mhz"
hwh = project / "zcu104_gemm_tiles_dma128_board_probe_100mhz.gen/sources_1/bd/system/hw_handoff/system.hwh"
required = [A / "zcu104_gemm_tiles_dma128_board_probe.bit",
            A / "zcu104_gemm_tiles_dma128_board_probe.xsa",
            A / "routed_timing_summary.rpt", A / "routed_utilization.rpt",
            A / "routed_drc.rpt", hwh,
            A / "smollm2_gemm_tiles_numeric_sd.elf",
            A / "smollm2_gemm_tiles_perf_sd.elf"]
for path in required:
    if not path.is_file():
        raise FileNotFoundError(path)
timing = (A / "routed_timing_summary.rpt").read_text(errors="replace")
if "timing constraints are met." not in timing.lower():
    raise RuntimeError("routed timing did not meet constraints")
shutil.copy2(hwh, A / "zcu104_gemm_tiles_dma128_board_probe.hwh")
shutil.copy2(D / "gemm_tiles_dma128_board_probe/README.md", A / "README.md")
with zipfile.ZipFile(A / "zcu104_gemm_tiles_dma128_board_probe.xsa") as xsa:
    if xsa.read("zcu104_gemm_tiles_dma128_board_probe.bit") != (A / "zcu104_gemm_tiles_dma128_board_probe.bit").read_bytes():
        raise RuntimeError("BIT and XSA contain different bitstreams")
    if xsa.read("system.hwh") != (A / "zcu104_gemm_tiles_dma128_board_probe.hwh").read_bytes():
        raise RuntimeError("HWH and XSA contain different hardware descriptions")
    (A / "psu_init.tcl").write_bytes(xsa.read("psu_init.tcl"))
files = [path for path in A.iterdir() if path.is_file() and
         path.name not in ("SHA256SUMS", "verification.json")]
files.sort()
(A / "SHA256SUMS").write_text("".join(
    f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n"
    for path in files))
archive = D / "gemm_tiles_dma128_board_handoff.tar.gz"
with tarfile.open(archive, "w:gz", compresslevel=6) as tar:
    for path in [*files, A / "SHA256SUMS"]:
        tar.add(path, arcname=path.name)
summary = {
    "bit_sha256": hashlib.sha256((A / "zcu104_gemm_tiles_dma128_board_probe.bit").read_bytes()).hexdigest(),
    "numeric_elf_sha256": hashlib.sha256((A / "smollm2_gemm_tiles_numeric_sd.elf").read_bytes()).hexdigest(),
    "perf_elf_sha256": hashlib.sha256((A / "smollm2_gemm_tiles_perf_sd.elf").read_bytes()).hexdigest(),
    "archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
    "board_execution": "pending",
}
(A / "verification.json").write_text(json.dumps(summary, indent=2) + "\n")
print(archive)
print(json.dumps(summary, indent=2))
