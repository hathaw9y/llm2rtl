#!/usr/bin/env python3
"""Check full-model handoff data and exact reused routed hardware identity."""
from pathlib import Path
import hashlib
import json
import re
import zipfile
D=Path(__file__).resolve().parents[1]
P=D/'full_model_board_probe'
A=P/'artifacts'
OLD=D/'first_layer_kv_board_probe/artifacts'
manifest=json.loads((P/'manifest.json').read_text())
program=json.loads((P/'program_verification.json').read_text())
assert program['prefill']['wire_records_exact'] and program['prefill']['interpreter_logits_exact']
assert program['decode']['wire_records_exact'] and program['decode']['interpreter_logits_exact']
assert program['prefill']['app_chunks_with_layer_boundaries']==187
assert program['decode']['app_chunks_with_layer_boundaries']==185
assert P.joinpath('ddr_static_bf16.bin').stat().st_size==manifest['ddr_static_bytes']
assert hashlib.sha256((P/'ddr_static_bf16.bin').read_bytes()).hexdigest()==manifest['ddr_static_sha256']
assert manifest['ddr_base']+manifest['ddr_bytes_used']<=0x80000000
stem='zcu104_first_layer_kv_board_probe'
bit=(A/f'{stem}.bit').read_bytes()
assert bit==(OLD/f'{stem}.bit').read_bytes()
with zipfile.ZipFile(A/f'{stem}.xsa') as z:
    assert z.read(f'{stem}.bit')==bit
    assert z.read('system.hwh')==(A/f'{stem}.hwh').read_bytes()
timing=(A/'routed_timing_summary.rpt').read_text()
hit=re.search(r'\n\s*([+-]?\d+\.\d+)\s+0\.000\s+0\s+\d+\s+([+-]?\d+\.\d+)\s+0\.000\s+0\s+\d+',timing)
assert hit
wns,whs=map(float,hit.groups())
assert wns>=0 and whs>=0
assert 'All user specified timing constraints are met.' in timing
assert (A/'smollm2_full_model_30_layer_probe.elf').stat().st_size>100000
assert 'Design State : Fully Routed' in (A/'routed_drc.rpt').read_text()
result={'scope':'30-layer prefill32 and position-32 decode1 to 49152 BF16 logits',
        'checkpoint_revision':manifest['checkpoint_revision'],
        'ddr_static_bytes':manifest['ddr_static_bytes'],
        'ddr_total_reserved_bytes':manifest['ddr_bytes_used'],
        'ps_c_records_match_python_isa':True,
        'python_16_record_interpreter_matches_reference_logits':True,
        'bit_reused_from_layer0_kv':True,
        'bit_sha256':hashlib.sha256(bit).hexdigest(),
        'routed_setup_wns_ns':wns,'routed_hold_whs_ns':whs,
        'physical_board_status':'not_run',
        'numeric_acceptance_status':'pending_board_log'}
(A/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
