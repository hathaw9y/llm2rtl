#!/usr/bin/env python3
"""First-layer Q/K/V, causal score and attention-context BF16 vectors."""
import json
import math
from pathlib import Path

import torch
from transformers import AutoModelForCausalLM

design = Path(__file__).resolve().parents[1]
checkpoint = Path('/home/shmin/.cache/huggingface/hub/models--HuggingFaceTB--SmolLM2-135M/snapshots/93efa2f097d58c2a74874c7e644dbc9b0cee75a2')
source = design / 'golden/rope_checkpoint'
dest = design / 'golden/attention_checkpoint'
dest.mkdir(exist_ok=True)


def read_rope(case, kind, rows, heads):
    words = [int(x, 16) for x in (source / case / f'{kind}_expected_words.hex').read_text().split()]
    bits = [(w >> (16 * i)) & 0xffff for w in words for i in range(8)]
    return torch.tensor(bits, dtype=torch.uint16).view(torch.bfloat16).reshape(rows, heads, 64)


def write_words(path, tensor):
    bits = tensor.contiguous().view(torch.uint16).reshape(-1).tolist()
    assert len(bits) % 8 == 0
    path.write_text('\n'.join(f'{sum(bits[i+j] << (16*j) for j in range(8)):032x}'
                              for i in range(0, len(bits), 8)) + '\n')


torch.set_num_threads(4)
model = AutoModelForCausalLM.from_pretrained(
    str(checkpoint), local_files_only=True, dtype=torch.bfloat16,
    attn_implementation='eager').eval()
attn = model.model.layers[0].self_attn
write_words(dest / 'q_weight_tiles_words.hex',
            attn.q_proj.weight.detach().cpu().reshape(3, 192, 576))
captures = []
hook = attn.register_forward_pre_hook(
    lambda _module, args, kwargs: captures.append(kwargs['hidden_states'].detach().cpu().clone()),
    with_kwargs=True)
tokens = [(i * 17 + 11) % 49152 for i in range(33)]
with torch.inference_mode():
    first = model(torch.tensor([tokens[:32]]), use_cache=True, logits_to_keep=1)
    model(torch.tensor([[tokens[32]]]), past_key_values=first.past_key_values,
          use_cache=True, logits_to_keep=1)
hook.remove()
with torch.inference_mode():
    v_prefill = attn.v_proj(captures[0]).reshape(32, 3, 64)
    v_decode = attn.v_proj(captures[1]).reshape(1, 3, 64)

q_prefill = read_rope('prefill', 'q', 32, 9)
k_prefill = read_rope('prefill', 'k', 32, 3)
q_decode = read_rope('decode', 'q', 1, 9)
k_decode = read_rope('decode', 'k', 1, 3)
manifest = {'checkpoint_revision': checkpoint.name,
            'numeric': 'checkpoint BF16 Q/K/V; BF16 QK^T/8; FP32 causal softmax to BF16; BF16 probability-times-V',
            'cases': {}}
for name, q, k, v, start in (
    ('prefill32', q_prefill, k_prefill, v_prefill, 0),
    ('decode1', q_decode, torch.cat((k_prefill, k_decode)),
     torch.cat((v_prefill, v_decode)), 32),
):
    rows, _, _ = q.shape
    kv_len = k.shape[0]
    score = torch.einsum('rhd,thd->rht', q.float(), k.repeat_interleave(3, 1).float())
    score = (score * 0.125).to(torch.bfloat16)
    causal = torch.arange(kv_len)[None, :] <= (start + torch.arange(rows)[:, None])
    probability = torch.softmax(score.float().masked_fill(~causal[:, None, :],
                                                         -float('inf')), -1).to(torch.bfloat16)
    context = torch.einsum('rht,thd->rhd', probability.float(),
                           v.repeat_interleave(3, 1).float()).to(torch.bfloat16)
    score = score.masked_fill(~causal[:, None, :], 0)
    pad = math.ceil(kv_len / 8) * 8 - kv_len
    if pad:
        score = torch.nn.functional.pad(score, (0, pad))
        probability = torch.nn.functional.pad(probability, (0, pad))
    for label, data in (('q_words', q), ('k_cache_words', k), ('v_cache_words', v),
                        ('score_words', score), ('probability_words', probability),
                        ('context_words', context)):
        write_words(dest / f'{name}_{label}.hex', data)
    manifest['cases'][name] = {'query_start': start, 'm_count': rows,
                               'kv_len': kv_len, 'padded_len': kv_len + pad,
                               'q_words': rows * 72, 'kv_words': kv_len * 24,
                               'score_words': rows * 9 * ((kv_len + pad) // 8),
                               'context_words': rows * 72}
(dest / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')

# A short, fully routed command-stream test uses the decode Q with only the
# first cached K/V token. Each query head therefore has one valid score lane.
focused_k = k_prefill[:1].repeat_interleave(3, 1)
focused_v = v_prefill[:1].repeat_interleave(3, 1)
focused_score = (q_decode.float() * focused_k.float()).sum(-1).mul(0.125).to(torch.bfloat16)
focused_probability = torch.ones_like(focused_score)
write_words(dest / 'focused_score_words.hex',
            torch.nn.functional.pad(focused_score.unsqueeze(-1), (0, 7)))
write_words(dest / 'focused_probability_words.hex',
            torch.nn.functional.pad(focused_probability.unsqueeze(-1), (0, 7)))
write_words(dest / 'focused_context_words.hex', focused_v)
print(dest)
