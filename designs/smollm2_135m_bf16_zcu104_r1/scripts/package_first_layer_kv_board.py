#!/usr/bin/env python3
"""Package the matched layer-0 KV board handoff."""
from pathlib import Path
import hashlib
import tarfile
D=Path(__file__).resolve().parents[1]
P=D/'first_layer_kv_board_probe'
A=P/'artifacts'
stem='zcu104_first_layer_kv_board_probe'
files=[P/'README.md',P/'manifest.json',P/'main.c',P/'vectors.h',
       D/'first_layer_no_kv_board_probe/vectors.h',
       D/'rtl/smollm2_dma_gemm_board_probe.sv',
       D/'rtl/smollm2_first_layer_kv_board_probe_bd.v',
       D/'scripts/check_first_layer_kv_isa_candidate.py',
       D/'scripts/generate_first_layer_kv_board_vectors.py',
       D/'scripts/create_first_layer_kv_board_probe_100mhz.tcl',
       D/'scripts/build_first_layer_kv_board_probe_100mhz.tcl',
       D/'scripts/build_first_layer_kv_board_app.py',
       D/'scripts/verify_first_layer_kv_board_artifacts.py',
       A/'SHA256SUMS',A/'run_on_zcu104.tcl',A/'psu_init.tcl',
       A/'verification.json',
       A/'routed_timing_summary.rpt',A/'routed_utilization.rpt',A/'routed_drc.rpt',
       *(A/f'{stem}.{ext}' for ext in ('bit','hwh','xsa','elf'))]
for file in files:
    if not file.is_file(): raise FileNotFoundError(file)
archive=D/'first_layer_kv_board_handoff.tar.gz'
with tarfile.open(archive,'w:gz') as tar:
    for file in files: tar.add(file,arcname=file.relative_to(D))
print(archive)
print(hashlib.sha256(archive.read_bytes()).hexdigest())
