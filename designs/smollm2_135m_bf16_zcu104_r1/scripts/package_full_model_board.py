#!/usr/bin/env python3
"""Package exact 30-layer board artifacts and static checkpoint DDR image."""
from pathlib import Path
import hashlib
import tarfile
D=Path(__file__).resolve().parents[1]
P=D/'full_model_board_probe'
A=P/'artifacts'
stem='zcu104_first_layer_kv_board_probe'
files=[P/name for name in ('README.md','manifest.json','program_verification.json',
    'ddr_static_bf16.bin','golden.h','address_map.h','main.c','program.c',
    'program.h','program_trace.c','trace_prefill.hex','trace_decode.hex')]
files += [A/name for name in ('verification.json','SHA256SUMS',
    'run_on_zcu104.tcl','psu_init.tcl',
    'smollm2_full_model_30_layer_probe.elf','routed_timing_summary.rpt',
    'routed_utilization.rpt','routed_drc.rpt',
    f'{stem}.bit',f'{stem}.hwh',f'{stem}.xsa')]
files += [D/'scripts'/name for name in ('generate_full_model_board_assets.py',
    'verify_full_model_board_program.py','verify_full_model_board_artifacts.py',
    'build_full_model_board_app.py','package_full_model_board.py',
    'check_first_layer_kv_isa_candidate.py')]
for path in files:
    if not path.is_file(): raise FileNotFoundError(path)
archive=D/'full_model_board_handoff.tar.gz'
with tarfile.open(archive,'w:gz',compresslevel=6) as tar:
    for path in files: tar.add(path,arcname=path.relative_to(D))
print(archive)
print(hashlib.sha256(archive.read_bytes()).hexdigest())
