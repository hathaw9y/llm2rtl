#!/usr/bin/env python3
"""Finalize a routed profile build; fail if timing or BIT/XSA identity fails."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import tarfile
import zipfile
D=Path(__file__).resolve().parents[1]
A=D/'perf128_board_probe/artifacts'
if 'all user specified timing constraints are met.' not in (A/'routed_timing_summary.rpt').read_text().lower():
    raise RuntimeError('routed timing failed')
route=(A/'routed_route_status.rpt').read_text()
route_errors=re.search(r'# of nets with routing errors\.+\s*:\s*(\d+)', route)
if not route_errors or int(route_errors[1]) != 0:
    raise RuntimeError('routing errors or missing route status')
drc=(A/'routed_drc.rpt').read_text()
if re.search(r'\|\s*(?:Error|Critical Warning)\s*\|', drc):
    raise RuntimeError('routed DRC error or critical warning')
with zipfile.ZipFile(A/'zcu104_perf128_board_probe.xsa') as xsa:
    if xsa.read('zcu104_perf128_board_probe.bit') != (A/'zcu104_perf128_board_probe.bit').read_bytes():
        raise RuntimeError('BIT/XSA mismatch')
    (A/'psu_init.tcl').write_bytes(xsa.read('psu_init.tcl'))
    (A/'zcu104_perf128_board_probe.hwh').write_bytes(xsa.read('system.hwh'))
shutil.copy2(D/'perf128_board_probe/README.md',A/'README.md')
shutil.copy2(D/'scripts/analyze_pl_profile.py',A/'analyze_pl_profile.py')
shutil.copy2(D/'perf128_board_probe/evidence/build_sources.sha256',A/'build_sources.sha256')
lines=(A/'routed_timing_summary.rpt').read_text().splitlines()
for i,line in enumerate(lines):
    if line.strip().startswith('WNS(ns)'):
        timing=lines[i+2].split()
        break
else:
    raise RuntimeError('missing design timing summary')
util=(A/'routed_utilization.rpt').read_text()
resources={}
for key,label in [('lut','CLB LUTs'),('ff','CLB Registers'),('bram_tiles','Block RAM Tile'),('uram','URAM'),('dsp','DSPs')]:
    match=re.search(r'\|\s*'+re.escape(label)+r'\s*\|\s*([\d.]+)\s*\|',util)
    if not match:
        raise RuntimeError('missing resource: '+label)
    resources[key]=float(match[1]) if '.' in match[1] else int(match[1])
summary={
    'clock_mhz':100,
    'tool_version':'Vivado 2025.2',
    'dma_stream_bits':128,
    'ddr_port':'HP0_FPD, 128-bit',
    'routed_resources':resources,
    'setup_wns_ns':float(timing[0]),
    'hold_whs_ns':float(timing[4]),
    'pulse_width_slack_ns':float(timing[8]),
    'routing_errors':0,
    'drc_errors':0,
    'drc_critical_warnings':0,
    'drc_advisory_warnings':'see routed_drc.rpt',
    'bit_sha256':hashlib.sha256((A/'zcu104_perf128_board_probe.bit').read_bytes()).hexdigest(),
    'profile_elf_sha256':hashlib.sha256((A/'smollm2_perf128_sd.elf').read_bytes()).hexdigest(),
    'board_execution':'pending',
    'profile_values':'not measured on physical board',
}
(A/'verification.json').write_text(json.dumps(summary,indent=2)+'\n')
files=sorted(p for p in A.iterdir() if p.is_file() and p.name!='SHA256SUMS')
(A/'SHA256SUMS').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in files))
archive=D/'perf128_board_handoff.tar.gz'
with tarfile.open(archive,'w:gz') as tar:
    for p in files+[A/'SHA256SUMS']:
        tar.add(p,arcname=p.name)
print(A)
print(archive)
print(json.dumps(summary,indent=2))
