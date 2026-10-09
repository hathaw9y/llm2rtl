#!/usr/bin/env python3
"""Check the numerical domain of all checkpoint RoPE sites in two traces."""
import json
from pathlib import Path

import torch
from transformers import AutoModelForCausalLM
from transformers.models.llama.modeling_llama import apply_rotary_pos_emb

CHECKPOINT = Path("/home/shmin/.cache/huggingface/hub/models--HuggingFaceTB--SmolLM2-135M/snapshots/93efa2f097d58c2a74874c7e644dbc9b0cee75a2")
DEST = Path(__file__).resolve().parents[1] / "golden/rope_checkpoint/sweep.json"
torch.set_num_threads(4)
model = AutoModelForCausalLM.from_pretrained(
    str(CHECKPOINT), local_files_only=True, dtype=torch.bfloat16,
    attn_implementation="eager").eval()
captures = [[None] * 30 for _ in range(2)]
case_index = [0]
handles = []
for layer, attention in enumerate(model.model.layers):
    def make_hook(index):
        def capture(_module, _args, kwargs):
            captures[case_index[0]][index] = kwargs["hidden_states"].detach().cpu().clone()
        return capture
    handles.append(attention.self_attn.register_forward_pre_hook(
        make_hook(layer), with_kwargs=True))
tokens = [(i * 17 + 11) % 49152 for i in range(33)]
with torch.inference_mode():
    prefill = model(torch.tensor([tokens[:32]]), use_cache=True, logits_to_keep=1)
    case_index[0] = 1
    model(torch.tensor([[tokens[32]]]), past_key_values=prefill.past_key_values,
          use_cache=True, logits_to_keep=1)
for handle in handles:
    handle.remove()

record = {"checkpoint_revision": CHECKPOINT.name, "cases": {}}
for case_name, captured, start in (("prefill32", captures[0], 0),
                                   ("decode1", captures[1], 32)):
    counts = {"layers": 0, "input_elements": 0, "output_elements": 0,
              "input_nonfinite": 0, "input_subnormal": 0,
              "output_nonfinite": 0, "output_subnormal": 0,
              "max_input_abs": 0.0, "max_output_abs": 0.0}
    with torch.inference_mode():
        for layer, x in enumerate(captured):
            attention = model.model.layers[layer].self_attn
            rows = x.shape[1]
            q = attention.q_proj(x).reshape(1, rows, 9, 64).transpose(1, 2)
            k = attention.k_proj(x).reshape(1, rows, 3, 64).transpose(1, 2)
            cos, sin = model.model.rotary_emb(
                x, torch.arange(start, start + rows)[None, :])
            q_out, k_out = apply_rotary_pos_emb(q, k, cos, sin)
            for tensor, destination in ((q, "input"), (k, "input"),
                                        (cos, "input"), (sin, "input"),
                                        (q_out, "output"), (k_out, "output")):
                bits = tensor.contiguous().view(torch.int16).to(torch.int32) & 0xffff
                exponent = (bits >> 7) & 255
                counts[f"{destination}_elements"] += tensor.numel()
                counts[f"{destination}_nonfinite"] += int((exponent == 255).sum())
                counts[f"{destination}_subnormal"] += int(
                    ((exponent == 0) & ((bits & 127) != 0)).sum())
                counts[f"max_{destination}_abs"] = max(
                    counts[f"max_{destination}_abs"],
                    float(tensor.float().abs().max()))
            counts["layers"] += 1
    record["cases"][case_name] = counts
DEST.write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
