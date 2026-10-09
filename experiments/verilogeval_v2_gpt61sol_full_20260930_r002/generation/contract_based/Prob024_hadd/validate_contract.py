#!/usr/bin/env python3
"""Structural benchmark contract gate, not a functional correctness proof."""
import hashlib
import json
import time
from pathlib import Path

path = Path('contract.json')
data = json.loads(path.read_text())
assert data.get('status') == 'frozen', 'Contract must be frozen'
for field in ('interface', 'semantics', 'numeric', 'verification'):
    assert isinstance(data.get(field), dict) and data[field], f'Missing {field}'
assert isinstance(data.get('specification_ambiguities'), list), 'Missing ambiguity list'
report = {'status': 'passed_structure_only', 'checked_at_unix': time.time(),
          'contract_sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
Path('contract_gate.json').write_text(json.dumps(report, indent=2) + '\n')
with Path('contract_gate_history.jsonl').open('a') as stream:
    stream.write(json.dumps(report) + '\n')
print(json.dumps(report))
