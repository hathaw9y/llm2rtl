#!/usr/bin/env python3
"""Package the matched FFN-intermediate ZCU104 BIT/XSA/ELF and host analyzer."""
from pathlib import Path
import hashlib
import tarfile

design = Path(__file__).resolve().parents[1]
probe = design / "first_layer_ffn_board_probe"
artifacts = probe / "artifacts"
stem = "zcu104_first_layer_ffn_board_probe"
files = [
    probe / "README.md",
    probe / "manifest.json",
    probe / "ffn_vectors.h",
    probe / "board_uart_ffn_rev2.txt",
    probe / "board_ffn_analysis_rev2.json",
    probe / "board_stage_analysis_rev2.json",
    design / "first_layer_stage_board_probe/stage_vectors.h",
    design / "first_layer_full_output_board_probe/full_output_vectors.h",
    design / "first_layer_no_kv_board_probe/main.c",
    design / "rtl/smollm2_dma_gemm_board_probe.sv",
    design / "rtl/smollm2_first_layer_ffn_board_probe_bd.v",
    design / "scripts/create_first_layer_ffn_board_probe_100mhz.tcl",
    design / "scripts/build_first_layer_ffn_board_probe_100mhz.tcl",
    design / "scripts/build_first_layer_ffn_board_app.py",
    design / "scripts/analyze_first_layer_ffn_log.py",
    design / "scripts/analyze_first_layer_full_output_log.py",
    artifacts / "SHA256SUMS",
    artifacts / "verification.json",
    artifacts / "psu_init.tcl",
    artifacts / "run_on_zcu104.tcl",
    *(artifacts / f"{stem}.{ext}" for ext in ("bit", "xsa", "hwh", "elf")),
    artifacts / "routed_timing_summary.rpt",
    artifacts / "routed_utilization.rpt",
    artifacts / "routed_drc.rpt",
]
for path in files:
    if not path.is_file():
        raise FileNotFoundError(path)
bundle = design / "first_layer_ffn_board_handoff.tar.gz"
with tarfile.open(bundle, "w:gz") as archive:
    for path in files:
        archive.add(path, arcname=path.relative_to(design))
print(bundle)
print(hashlib.sha256(bundle.read_bytes()).hexdigest())
