#!/usr/bin/env python3
"""Package the matched full-output ZCU104 BIT/XSA/ELF and host analyzer."""
from pathlib import Path
import hashlib
import tarfile

design = Path(__file__).resolve().parents[1]
probe = design / "first_layer_full_output_board_probe"
artifacts = probe / "artifacts"
stem = "zcu104_first_layer_full_output_board_probe"
files = [
    probe / "README.md",
    probe / "manifest.json",
    probe / "full_output_vectors.h",
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
bundle = design / "first_layer_full_output_board_handoff.tar.gz"
with tarfile.open(bundle, "w:gz") as archive:
    for path in files:
        archive.add(path, arcname=path.relative_to(design))
print(bundle)
print(hashlib.sha256(bundle.read_bytes()).hexdigest())
