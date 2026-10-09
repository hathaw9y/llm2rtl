#!/usr/bin/env python3
"""Expand pinned-checkpoint q_proj operands to 16 output columns."""
import hashlib
import json
from fractions import Fraction
from pathlib import Path

import torch
import torch.nn.functional as F
from safetensors import safe_open

from generate_gemm_vectors import bf16_value, round_bf16

ROOT = Path(__file__).resolve().parents[1]
OLD = ROOT / "golden" / "gemm_model"
OUT = ROOT / "golden" / "gemm_systolic_model"
REVISION = "93efa2f097d58c2a74874c7e644dbc9b0cee75a2"
CHECKPOINT = (Path("/home/shmin/.cache/huggingface/hub/models--HuggingFaceTB--SmolLM2-135M/snapshots")
              / REVISION / "model.safetensors")


def read_hex(path: Path) -> list[int]:
    return [int(line, 16) for line in path.read_text().splitlines()]


def write_hex(path: Path, values: list[int]) -> None:
    path.write_text("".join(f"{value:04x}\n" for value in values))


def bits_to_tensor(values: list[int], shape: tuple[int, ...]) -> torch.Tensor:
    return torch.tensor(values, dtype=torch.uint16).view(torch.bfloat16).reshape(shape)


def bits_from_tensor(value: torch.Tensor) -> list[int]:
    return value.contiguous().view(torch.uint16).reshape(-1).tolist()


def main() -> None:
    torch.set_num_threads(4)
    prior = json.loads((OLD / "manifest.json").read_text())
    assert prior["checkpoint_revision"] == REVISION
    with safe_open(str(CHECKPOINT), framework="pt", device="cpu") as weights:
        weight = weights.get_tensor("model.layers.0.self_attn.q_proj.weight")[:16].contiguous()
    assert weight.dtype == torch.bfloat16 and weight.shape == (16, 576)
    OUT.mkdir(parents=True, exist_ok=True)
    weight_bits = bits_from_tensor(weight)
    write_hex(OUT / "weight16.hex", weight_bits)
    results = {}
    for name, selected_rows in (("prefill", (30, 31)), ("decode", (0,)),
                                ("prefill32", tuple(range(32)))):
        source_name = "decode" if name == "decode" else "prefill"
        activation_bits = read_hex(OLD / f"{source_name}_activation.hex")
        rows = 1 if name == "decode" else 32
        activation = bits_to_tensor(activation_bits, (rows, 576))
        exact = []
        for row in selected_rows:
            for column in range(16):
                dot = sum((bf16_value(activation_bits[row * 576 + k]) *
                           bf16_value(weight_bits[column * 576 + k])
                           for k in range(576)), Fraction())
                exact.append(round_bf16(dot))
        with torch.inference_mode():
            eager = bits_from_tensor(F.linear(activation[list(selected_rows)], weight))
        write_hex(OUT / f"{name}_exact16.hex", exact)
        write_hex(OUT / f"{name}_torch16.hex", eager)
        results[name] = {
            "selected_rows": list(selected_rows),
            "output_count": len(exact),
            "exact_vs_torch_equal_count": sum(a == b for a, b in zip(exact, eager)),
            "activation_sha256": hashlib.sha256((OLD / f"{source_name}_activation.hex").read_bytes()).hexdigest(),
        }
    manifest = {
        "checkpoint_revision": REVISION,
        "checkpoint_sha256": prior["model_safetensors_sha256"],
        "source_activation_manifest_sha256": hashlib.sha256((OLD / "manifest.json").read_bytes()).hexdigest(),
        "operation": "layer0.self_attn.q_proj BF16 F.linear, first 16 output columns",
        "results": results,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
