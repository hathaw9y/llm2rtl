#!/usr/bin/env python3
"""Check 32+8 prefill and decode ISA records plus KV continuation."""
from pathlib import Path
import json
import subprocess
import sys
import torch
from transformers import AutoModelForCausalLM

D = Path(__file__).resolve().parents[1]
P = D / 'full_model_board_probe'
I = D / 'interactive_board_probe'
sys.path.insert(0, str(D.parents[1] / 'verification/prototypes'))
import smollm2_135m_isa_feasibility as isa
sys.path.insert(0, str(D / 'scripts'))
from check_first_layer_kv_isa_candidate import check_dispatcher_roles

trace = Path('/tmp/smollm2_interactive_isa_trace')
subprocess.run(['gcc', '-std=c11', '-Wall', '-Wextra', '-Werror', '-O2',
                f'-I{P}', str(I / 'interactive_trace.c'), str(P / 'program.c'),
                '-o', str(trace)], check=True)
lines = subprocess.run([str(trace)], capture_output=True, text=True,
                       check=True).stdout.splitlines()
records = {}
current = None
for line in lines:
    if line.startswith('BEGIN '):
        _, start, rows, logits = line.split()
        current = (int(start), int(rows), int(logits))
        records[current] = []
    else:
        assert current is not None
        records[current].append(line)
assert list(records) == [(0, 32, 0), (32, 8, 1), (40, 1, 1)]

torch.set_num_threads(4)
model = AutoModelForCausalLM.from_pretrained(
    str(isa.CHECKPOINT), local_files_only=True, dtype=torch.bfloat16,
    attn_implementation='eager').eval()
ids = [(i * 17 + 11) % 49152 for i in range(41)]
ddr = isa.DDR(model, [])
machine = isa.Machine(ddr)
cache = None
result = {}
with torch.inference_mode():
    for key in records:
        start, rows, logits = key
        p = isa.build_block(ids[start:start + rows], start, bool(logits))
        check_dispatcher_roles(p)
        operations = [cmd for chunk in p.chunks for cmd in chunk
                      if cmd.op != 'END']
        if logits:
            operations.append(isa.Cmd('FENCE'))
            p.chunks[-1].insert(-1, isa.Cmd('FENCE'))
        expected = [f'{isa.wire_record(cmd, ddr):032x}'
                    for cmd in operations]
        assert records[key] == expected, key
        reference = model(torch.tensor([ids[start:start + rows]]),
                          past_key_values=cache, use_cache=True,
                          logits_to_keep=1)
        cache = reference.past_key_values
        actual = machine.run(p)
        if logits:
            assert torch.equal(actual, reference.logits[0]), key
        result[str(key)] = {'operations': len(operations),
                            'wire_exact': True,
                            'reference_logits_exact': bool(logits),
                            'top1': int(torch.argmax(reference.logits))}
(I / 'program_verification.json').write_text(json.dumps(result, indent=2)+'\n')
print(json.dumps(result, indent=2))
