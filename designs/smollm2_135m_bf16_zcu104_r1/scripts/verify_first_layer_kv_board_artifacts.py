#!/usr/bin/env python3
"""Read-only consistency and routed-evidence check for layer-0 KV handoff."""
from pathlib import Path
import hashlib
import json
import re
import zipfile
D=Path(__file__).resolve().parents[1]
P=D/'first_layer_kv_board_probe'
A=P/'artifacts'
stem='zcu104_first_layer_kv_board_probe'
manifest=json.loads((P/'manifest.json').read_text())
assert manifest['interpreter_reference_exact']
assert manifest['rtl_dispatcher_bank_roles_legal']
for evidence,name in [('smollm2_dma_bank_bridge','smollm2_dma_bank_bridge'),
                      ('smollm2_dma_control_fabric_wide','smollm2_dma_control_fabric_wide'),
                      ('isa_command_dispatcher','isa_command_dispatcher integration')]:
    run='run_004' if evidence=='isa_command_dispatcher' else 'run_001'
    log=(D/'evidence'/evidence/run/'xsim.log').read_text()
    assert f'PASS {name}' in log, (evidence,run)
bit=(A/f'{stem}.bit').read_bytes()
with zipfile.ZipFile(A/f'{stem}.xsa') as z:
    assert z.read(f'{stem}.bit')==bit
    assert z.read('system.hwh')==(A/f'{stem}.hwh').read_bytes()
timing=(A/'routed_timing_summary.rpt').read_text()
match=re.search(r'\n\s*([+-]?\d+\.\d+)\s+0\.000\s+0\s+\d+\s+([+-]?\d+\.\d+)\s+0\.000\s+0\s+\d+',timing)
assert match, 'timing summary not found'
wns,whs=map(float,match.groups())
assert wns>=0 and whs>=0 and 'All user specified timing constraints are met.' in timing
util=(A/'routed_utilization.rpt').read_text()
def resource(label):
    hit=re.search(r'^\|\s*'+re.escape(label)+r'\s*\|\s*(\d+)\s*\|',util,re.M)
    assert hit,label
    return int(hit.group(1))
drc=(A/'routed_drc.rpt').read_text()
assert 'Design State : Fully Routed' in drc
assert not re.search(r'^\|[^|]+\|\s*Error\s*\|',drc,re.M)
assert (A/f'{stem}.elf').stat().st_size>1000000
report={'scope':'layer 0 prefill32 then position-32 decode1 with PL K/V DDR roundtrip',
        'checkpoint_revision':manifest['checkpoint_revision'],
        'interpreter_reference_exact':True,
        's2mm_bridge_xsim':'PASS',
        'dma_control_fabric_xsim':'PASS',
        'dispatcher_xsim':'PASS after fixing testbench SILU row count from 0 to 1',
        'vivado_version':'2025.2', 'clock_mhz':100,
        'routed_setup_wns_ns':wns,'routed_hold_whs_ns':whs,
        'routed_drc_errors':0,
        'routed_resources':{'lut_logic':resource('LUT as Logic'),
                            'bram_tiles':resource('Block RAM Tile'),
                            'uram':resource('URAM'),
                            'dsp':resource('DSPs')},
        'bit_sha256':hashlib.sha256(bit).hexdigest(),
        'xsa_contains_matching_bit':True,
        'physical_board_status':'not_run'}
(A/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
