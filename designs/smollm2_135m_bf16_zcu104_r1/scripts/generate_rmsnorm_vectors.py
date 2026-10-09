#!/usr/bin/env python3
"""Deterministic SmolLM2 RMSNorm vectors with BF16 cast boundaries."""
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1] / "golden" / "rmsnorm"
ROOT.mkdir(parents=True, exist_ok=True)


def bf16_round(values):
    bits = np.asarray(values, dtype=np.float32).view(np.uint32)
    bias = np.uint32(0x7FFF) + ((bits >> 16) & 1)
    return ((bits + bias) >> 16).astype(np.uint16)


def bf16_float(bits):
    return (bits.astype(np.uint32) << 16).view(np.float32)


def words(bits):
    for group in bits.reshape(-1, 8):
        yield "".join(f"{int(v):04x}" for v in group[::-1])


rows, width = 32, 576
rng = np.random.default_rng(135)
x = rng.normal(0, 0.7, (rows, width)).astype(np.float32)
gamma = rng.uniform(0.4, 1.3, width).astype(np.float32)
x_bits = bf16_round(x)
gamma_bits = bf16_round(gamma)
x_bf = bf16_float(x_bits)
gamma_bf = bf16_float(gamma_bits)
mean = np.mean(x_bf * x_bf, axis=-1, keepdims=True, dtype=np.float32)
normalized = x_bf * (1.0 / np.sqrt(mean + np.float32(1e-5)))
normalized_bits = bf16_round(normalized)
result_bits = bf16_round(bf16_float(normalized_bits) * gamma_bf)

(ROOT / "input_words.hex").write_text("\n".join(words(x_bits)) + "\n")
(ROOT / "gamma_words.hex").write_text("\n".join(words(gamma_bits)) + "\n")
(ROOT / "expected_words.hex").write_text("\n".join(words(result_bits)) + "\n")
print(f"generated {rows}x{width} RMSNorm BF16 vectors in {ROOT}")
