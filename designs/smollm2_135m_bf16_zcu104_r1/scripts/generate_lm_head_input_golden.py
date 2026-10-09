#!/usr/bin/env python3
"""Freeze first 16 BF16 values entering lm_head for the board token sequence."""
from pathlib import Path
import json
import sys
import torch
from torch.nn import functional as F
from transformers import AutoModelForCausalLM

D = Path(__file__).resolve().parents[1]
P = D / 'full_model_board_probe'
sys.path.insert(0, str(D.parents[1] / 'verification/prototypes'))
from smollm2_135m_isa_feasibility import CHECKPOINT

manifest = json.loads((P / 'manifest.json').read_text())
torch.set_num_threads(4)
model = AutoModelForCausalLM.from_pretrained(
    str(CHECKPOINT), local_files_only=True, dtype=torch.bfloat16,
    attn_implementation='eager').eval()
assert manifest['checkpoint_revision'] == '93efa2f097d58c2a74874c7e644dbc9b0cee75a2'
cache = None
vectors = {}
with torch.inference_mode():
    for name in ('prefill', 'decode'):
        ids = manifest[f'{name}_tokens']
        result = model(torch.tensor([ids]), past_key_values=cache,
                       use_cache=True, logits_to_keep=1,
                       output_hidden_states=True)
        cache = result.past_key_values
        hidden = result.hidden_states[-1][0, -1]
        assert torch.equal(F.linear(hidden, model.lm_head.weight),
                           result.logits[0, -1])
        vectors[name] = hidden[:16].view(torch.int16).tolist()
lines = ['#ifndef SMOLLM2_LM_HEAD_INPUT_GOLDEN_H',
         '#define SMOLLM2_LM_HEAD_INPUT_GOLDEN_H', '#include <stdint.h>']
for name, values in vectors.items():
    bits = [v & 0xffff for v in values]
    lines += [f'static const uint16_t expected_{name}_lm_input_first16[16] = {{',
              ','.join(f'0x{v:04x}u' for v in bits), '};']
lines += ['#endif', '']
(P / 'lm_head_input_golden.h').write_text('\n'.join(lines))
print({name: [f'{v & 0xffff:04x}' for v in values]
       for name, values in vectors.items()})
