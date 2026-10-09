#!/usr/bin/env python3
"""Capture first-layer SmolLM2 RMSNorm prefill/decode input and BF16 result."""
from pathlib import Path
import shutil
import torch
from transformers import AutoModelForCausalLM

CHECKPOINT = Path("/home/shmin/.cache/huggingface/hub/models--HuggingFaceTB--SmolLM2-135M/snapshots/93efa2f097d58c2a74874c7e644dbc9b0cee75a2")
DEST = Path(__file__).resolve().parents[1] / "golden" / "rmsnorm_checkpoint"
DEST.mkdir(exist_ok=True)


def words(tensor):
    values = tensor.contiguous().reshape(-1).view(torch.int16).tolist()
    for i in range(0, len(values), 8):
        yield "".join(f"{value & 0xffff:04x}" for value in values[i:i+8][::-1])


def save(name, tensor):
    (DEST / name).write_text("\n".join(words(tensor)) + "\n")


torch.set_num_threads(4)
model = AutoModelForCausalLM.from_pretrained(
    str(CHECKPOINT), local_files_only=True, dtype=torch.bfloat16,
    attn_implementation="eager").eval()
norm = model.model.layers[0].input_layernorm
gamma = norm.weight.detach().cpu()
captures = []


def capture(_module, args, _output):
    captures.append(args[0].detach().cpu()[0].clone())


handle = norm.register_forward_hook(capture)
tokens = [(i * 17 + 11) % 49152 for i in range(33)]
with torch.inference_mode():
    prefill = model(torch.tensor([tokens[:32]]), use_cache=True,
                    logits_to_keep=1)
    model(torch.tensor([[tokens[32]]]),
          past_key_values=prefill.past_key_values, use_cache=True,
          logits_to_keep=1)
handle.remove()
assert [tuple(x.shape) for x in captures] == [(32, 576), (1, 576)]
save("gamma_words.hex", gamma)
for name, x in zip(("prefill", "decode"), captures):
    y = x.float() * torch.rsqrt(x.float().pow(2).mean(-1, keepdim=True) + 1e-5)
    expected = gamma * y.to(torch.bfloat16)
    save(f"{name}_input_words.hex", x)
    save(f"{name}_expected_words.hex", expected)
    case_dir = DEST / name
    case_dir.mkdir(exist_ok=True)
    shutil.copyfile(DEST / "gamma_words.hex", case_dir / "gamma_words.hex")
    shutil.copyfile(DEST / f"{name}_input_words.hex", case_dir / "input_words.hex")
    shutil.copyfile(DEST / f"{name}_expected_words.hex", case_dir / "expected_words.hex")
    print(name, tuple(x.shape), "max_abs", float(x.float().abs().max()))
print(DEST)
