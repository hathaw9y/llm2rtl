#!/usr/bin/env python3
"""Pin first-layer Q/K RoPE words and reference outputs for prefill/decode."""
import json
from pathlib import Path

import torch
from transformers import AutoModelForCausalLM
from transformers.models.llama.modeling_llama import apply_rotary_pos_emb

CHECKPOINT = Path("/home/shmin/.cache/huggingface/hub/models--HuggingFaceTB--SmolLM2-135M/snapshots/93efa2f097d58c2a74874c7e644dbc9b0cee75a2")
DEST = Path(__file__).resolve().parents[1] / "golden" / "rope_checkpoint"
DEST.mkdir(parents=True, exist_ok=True)


def save_words(path: Path, tensor: torch.Tensor):
    values = tensor.contiguous().reshape(-1).view(torch.int16).tolist()
    assert len(values) % 8 == 0
    path.write_text("\n".join(
        "".join(f"{value & 0xffff:04x}" for value in values[i:i+8][::-1])
        for i in range(0, len(values), 8)) + "\n")


torch.set_num_threads(4)
model = AutoModelForCausalLM.from_pretrained(
    str(CHECKPOINT), local_files_only=True, dtype=torch.bfloat16,
    attn_implementation="eager").eval()
attention = model.model.layers[0].self_attn
captures = []
hook = attention.register_forward_pre_hook(
    lambda _module, args, kwargs: captures.append(
        kwargs["hidden_states"].detach().cpu().clone()), with_kwargs=True)
tokens = [(i * 17 + 11) % 49152 for i in range(33)]
with torch.inference_mode():
    prefill = model(torch.tensor([tokens[:32]]), use_cache=True, logits_to_keep=1)
    model(torch.tensor([[tokens[32]]]), past_key_values=prefill.past_key_values,
          use_cache=True, logits_to_keep=1)
hook.remove()
assert [tuple(x.shape) for x in captures] == [(1, 32, 576), (1, 1, 576)]

manifest = {"checkpoint_revision": CHECKPOINT.name, "cases": {}}
for label, x, start in (("prefill", captures[0], 0),
                        ("decode", captures[1], 32),
                        ("prefill_tail", captures[0], 992)):
    rows = x.shape[1]
    with torch.inference_mode():
        q = attention.q_proj(x).reshape(1, rows, 9, 64).transpose(1, 2)
        k = attention.k_proj(x).reshape(1, rows, 3, 64).transpose(1, 2)
        cos, sin = model.model.rotary_emb(
            x, torch.arange(start, start + rows)[None, :])
        q_expected, k_expected = apply_rotary_pos_emb(q, k, cos, sin)
    coeff = torch.cat((cos[0, :, :32], sin[0, :, :32]), dim=-1)
    case = DEST / label
    case.mkdir(exist_ok=True)
    save_words(case / "coeff_words.hex", coeff)
    for name, data, expected in (("q", q, q_expected), ("k", k, k_expected)):
        save_words(case / f"{name}_input_words.hex",
                   data[0].transpose(0, 1).contiguous())
        save_words(case / f"{name}_expected_words.hex",
                   expected[0].transpose(0, 1).contiguous())
    manifest["cases"][label] = {"rows": rows, "position_start": start,
                                 "q_elements": rows * 576,
                                 "k_elements": rows * 192}
(DEST / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest, indent=2))
