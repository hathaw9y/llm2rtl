#!/usr/bin/env python3
"""Check the RTL reduction approximation across every checkpoint RMSNorm call."""
from pathlib import Path
import json
import math
import numpy as np
import torch
from transformers import AutoModelForCausalLM

CHECKPOINT = Path("/home/shmin/.cache/huggingface/hub/models--HuggingFaceTB--SmolLM2-135M/snapshots/93efa2f097d58c2a74874c7e644dbc9b0cee75a2")
DEST = Path(__file__).resolve().parents[1] / "golden" / "rmsnorm_checkpoint"


def words(tensor):
    values = tensor.contiguous().reshape(-1).view(torch.int16).tolist()
    for i in range(0, len(values), 8):
        yield "".join(f"{v & 0xffff:04x}" for v in values[i:i + 8][::-1])


def ordered(bits):
    bits = bits.astype(np.uint32)
    return np.where(bits & 0x8000, 0xffff - bits, bits + 0x8000).astype(np.int32)


torch.set_num_threads(4)
model = AutoModelForCausalLM.from_pretrained(
    str(CHECKPOINT), local_files_only=True, dtype=torch.bfloat16,
    attn_implementation="eager").eval()
records = []
worst = {"max_ulp": -1}
largest_abs = -1.0
handles = []


def make_hook(layer, name):
    def hook(module, args, output):
        global worst, largest_abs
        x = args[0].detach().cpu()[0]
        reference = output.detach().cpu()[0]
        gamma = module.weight.detach().cpu()
        x_np = x.float().numpy().astype(np.float64)
        x_q16 = np.trunc(x_np * 65536.0).astype(np.int64)
        mean_q32 = (x_q16 * x_q16).sum(axis=1) // 576 + 42950
        sqrt_q16 = np.array([math.isqrt(int(v)) for v in mean_q32], dtype=np.int64)
        inv_q32 = np.array([(1 << 48) // int(v) for v in sqrt_q16], dtype=np.int64)
        approximate = torch.from_numpy(
            (x_np * (inv_q32[:, None] / (1 << 32))).astype(np.float32)
        ).to(torch.bfloat16)
        candidate = gamma * approximate
        actual_bits = candidate.view(torch.int16).numpy().astype(np.uint16)
        ref_bits = reference.view(torch.int16).numpy().astype(np.uint16)
        ulps = np.abs(ordered(actual_bits) - ordered(ref_bits))
        item = {
            "layer": layer, "norm": name, "rows": int(x.shape[0]),
            "max_abs_input": float(x.float().abs().max()),
            "max_ulp": int(ulps.max()), "over_2_ulp": int(np.count_nonzero(ulps > 2)),
            "elements": int(ulps.size),
        }
        records.append(item)
        if item["max_ulp"] > worst["max_ulp"]:
            worst = item
            case = DEST / "extreme"
            case.mkdir(parents=True, exist_ok=True)
            for filename, tensor in (("input_words.hex", x),
                                     ("gamma_words.hex", gamma),
                                     ("expected_words.hex", reference)):
                (case / filename).write_text("\n".join(words(tensor)) + "\n")
        if item["rows"] == 32 and item["max_abs_input"] > largest_abs:
            largest_abs = item["max_abs_input"]
            case = DEST / "large_input"
            case.mkdir(parents=True, exist_ok=True)
            for filename, tensor in (("input_words.hex", x),
                                     ("gamma_words.hex", gamma),
                                     ("expected_words.hex", reference)):
                (case / filename).write_text("\n".join(words(tensor)) + "\n")
    return hook


for layer, block in enumerate(model.model.layers):
    for name in ("input_layernorm", "post_attention_layernorm"):
        handles.append(getattr(block, name).register_forward_hook(make_hook(layer, name)))
tokens = [(i * 17 + 11) % 49152 for i in range(33)]
with torch.inference_mode():
    prefill = model(torch.tensor([tokens[:32]]), use_cache=True,
                    logits_to_keep=1)
    model(torch.tensor([[tokens[32]]]),
          past_key_values=prefill.past_key_values, use_cache=True,
          logits_to_keep=1)
for handle in handles:
    handle.remove()
summary = {
    "checkpoint_revision": CHECKPOINT.name,
    "calls": len(records),
    "elements": sum(r["elements"] for r in records),
    "over_2_ulp": sum(r["over_2_ulp"] for r in records),
    "max_ulp": max(r["max_ulp"] for r in records),
    "max_abs_input": max(r["max_abs_input"] for r in records),
    "worst": worst,
    "records": records,
    "scope": "first 32 tokens then one decode token; all 60 RMSNorm sites, numerical model of RTL reduction and BF16 casts",
}
(DEST / "sweep.json").write_text(json.dumps(summary, indent=2) + "\n")
print(json.dumps({k: v for k, v in summary.items() if k != "records"}, indent=2))
