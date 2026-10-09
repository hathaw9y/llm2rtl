#!/usr/bin/env python3
"""Capture real SmolLM2 BF16 Q-projection operands for GEMM RTL comparison."""
import json
import struct
import hashlib
from fractions import Fraction
from pathlib import Path

import torch
import torch.nn.functional as F
from transformers import AutoModelForCausalLM

from generate_gemm_vectors import bf16_value, round_bf16

REVISION = "93efa2f097d58c2a74874c7e644dbc9b0cee75a2"
CHECKPOINT = Path("/home/shmin/.cache/huggingface/hub/models--HuggingFaceTB--SmolLM2-135M/snapshots") / REVISION
OUT = Path(__file__).resolve().parents[1] / "golden" / "gemm_model"


def bits(tensor: torch.Tensor) -> list[int]:
    assert tensor.dtype == torch.bfloat16
    return tensor.contiguous().view(torch.uint16).reshape(-1).tolist()


def save_hex(name: str, data: list[int]) -> None:
    (OUT / name).write_text("".join(f"{value:04x}\n" for value in data))


def float_from_bf16(value: int) -> float:
    return struct.unpack("<f", struct.pack("<I", value << 16))[0]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    torch.set_num_threads(4)
    model = AutoModelForCausalLM.from_pretrained(
        str(CHECKPOINT), local_files_only=True, dtype=torch.bfloat16,
        attn_implementation="eager").eval()
    module = model.model.layers[0].self_attn.q_proj
    captured: list[torch.Tensor] = []
    hook = module.register_forward_pre_hook(
        lambda _module, args: captured.append(args[0].detach().cpu().clone()))
    token_ids = [(i * 17 + 11) % 49152 for i in range(33)]
    with torch.inference_mode():
        prefill = model(torch.tensor([token_ids[:32]]), use_cache=True,
                        logits_to_keep=1)
        model(torch.tensor([[token_ids[32]]]),
              past_key_values=prefill.past_key_values, use_cache=True,
              logits_to_keep=1)
    hook.remove()
    assert len(captured) == 2
    prefill_act = captured[0][0].contiguous()
    decode_act = captured[1][0].contiguous()
    weight = module.weight.detach().cpu()[:4].contiguous()
    assert prefill_act.shape == (32, 576)
    assert decode_act.shape == (1, 576)
    assert weight.shape == (4, 576)
    OUT.mkdir(parents=True, exist_ok=True)
    save_hex("model_weight.hex", bits(weight))
    results = {}
    for name, activation in (("prefill", prefill_act[30:32]),
                             ("decode", decode_act)):
        source = prefill_act if name == "prefill" else decode_act
        source_bits = bits(source)
        weight_bits = bits(weight)
        exact = []
        for row in range(activation.shape[0]):
            source_row = 30 + row if name == "prefill" else row
            for column in range(4):
                dot = sum((bf16_value(source_bits[source_row * 576 + k]) *
                           bf16_value(weight_bits[column * 576 + k])
                           for k in range(576)), Fraction())
                exact.append(round_bf16(dot))
        with torch.inference_mode():
            eager = bits(F.linear(activation, weight))
        save_hex(f"{name}_activation.hex", source_bits)
        save_hex(f"{name}_exact.hex", exact)
        save_hex(f"{name}_torch.hex", eager)
        differences = [abs(float_from_bf16(a) - float_from_bf16(b))
                       for a, b in zip(exact, eager)]
        results[name] = {
            "activation_shape": list(source.shape),
            "selected_rows": [30, 31] if name == "prefill" else [0],
            "weight_shape": list(weight.shape),
            "output_count": len(exact),
            "exact_vs_torch_equal_count": sum(a == b for a, b in zip(exact, eager)),
            "exact_vs_torch_max_abs": max(differences),
            "exact_bf16_bits": [f"{x:04x}" for x in exact],
            "torch_bf16_bits": [f"{x:04x}" for x in eager]
        }
    manifest = {
        "checkpoint_revision": REVISION,
        "model_safetensors_sha256": sha256_file(CHECKPOINT / "model.safetensors"),
        "config_sha256": sha256_file(CHECKPOINT / "config.json"),
        "model": "HuggingFaceTB/SmolLM2-135M",
        "operation": "layer0.self_attn.q_proj BF16 F.linear, first four output columns",
        "token_ids": token_ids,
        "torch_version": torch.__version__,
        "results": results
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
