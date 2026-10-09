#!/usr/bin/env python3
"""Pin DDR inputs and offline golden for the cumulative RoPE board probe."""
import json
import math
from pathlib import Path

import numpy as np
import torch
from transformers.models.llama.modeling_llama import apply_rotary_pos_emb

design = Path(__file__).resolve().parents[1]
rms = design / "golden/rmsnorm_checkpoint"
rope = design / "golden/rope_checkpoint"
dest = design / "dma_rms_gemm_rope_board_probe"
dest.mkdir(exist_ok=True)


def read_words(path):
    return [int(line, 16) for line in path.read_text().splitlines()]


def tensor(words, rows, width):
    bits = [(word >> (16 * lane)) & 0xffff for word in words for lane in range(8)]
    return torch.tensor(bits, dtype=torch.uint16).view(torch.bfloat16).reshape(rows, width)


def c_words(label, values):
    lines = [f"static const uint32_t {label}[{len(values)}][4] = {{"]
    for value in values:
        lines.append("    {" + ", ".join(
            f"0x{(value >> (32*i)) & 0xffffffff:08x}u" for i in range(4)
        ) + "},")
    return "\n".join(lines + ["};"])


def c_first16(label, bits):
    values = bits.contiguous().view(torch.uint16).reshape(-1).tolist()
    return (f"static const uint16_t {label}[{len(values)}] = {{\n" +
            "\n".join("    " + ", ".join(f"0x{v:04x}u" for v in values[i:i+16]) + ","
                      for i in range(0, len(values), 16)) + "\n};")


weight = []
for n in range(192):
    for k_word in range(72):
        value = 0x3f80 << (16 * (n % 8)) if k_word == n // 8 else 0
        weight.append(value)
(dest / "onehot192_words.hex").write_text(
    "\n".join(f"{value:032x}" for value in weight) + "\n")
gamma_words = read_words(rms / "gamma_words.hex")
gamma = tensor(gamma_words, 1, 576)[0]
cases = {}
for label, rows in (("prefill", 32), ("decode", 1)):
    source = read_words(rms / f"{label}_input_words.hex")
    coeff = read_words(rope / label / "coeff_words.hex")
    x = tensor(source, rows, 576)
    x_np = x.float().numpy().astype(np.float64)
    x_q16 = np.trunc(x_np * 65536.0).astype(np.int64)
    mean_q32 = (x_q16 * x_q16).sum(axis=1) // 576 + 42950
    sqrt_q16 = np.array([math.isqrt(int(v)) for v in mean_q32], dtype=np.int64)
    inv_q32 = np.array([(1 << 48) // int(v) for v in sqrt_q16], dtype=np.int64)
    norm = torch.from_numpy(
        (x_np * (inv_q32[:, None] / (1 << 32))).astype(np.float32)
    ).to(torch.bfloat16) * gamma
    projected = norm[:, :192]
    q = projected.repeat(1, 3).reshape(1, rows, 9, 64).transpose(1, 2)
    k = projected.reshape(1, rows, 3, 64).transpose(1, 2)
    coeff_tensor = tensor(coeff, rows, 64)
    cos = torch.cat((coeff_tensor[:, :32], coeff_tensor[:, :32]), -1)[None, :, :]
    sin = torch.cat((coeff_tensor[:, 32:], coeff_tensor[:, 32:]), -1)[None, :, :]
    q_out, k_out = apply_rotary_pos_emb(q, k, cos, sin)
    q_first = q_out[0].transpose(0, 1).reshape(rows, 576)[:, :16]
    k_first = k_out[0].transpose(0, 1).reshape(rows, 192)[:, :16]
    cases[label] = {"rows": rows, "input_words": source,
                    "coeff_words": coeff, "q_first": q_first,
                    "k_first": k_first}
    for name, values in (("input", source), ("coeff", coeff)):
        (dest / f"{label}_{name}_words.hex").write_text(
            "\n".join(f"{value:032x}" for value in values) + "\n")
    for name, values in (("q", q_first), ("k", k_first)):
        bits = values.contiguous().view(torch.uint16).reshape(-1).tolist()
        (dest / f"{label}_{name}_first16.hex").write_text(
            "\n".join(f"{value:04x}" for value in bits) + "\n")

parts = ["#ifndef SMOLLM2_RMS_GEMM_ROPE_BOARD_VECTORS_H",
         "#define SMOLLM2_RMS_GEMM_ROPE_BOARD_VECTORS_H", "#include <stdint.h>",
         c_words("prefill_input_words", cases["prefill"]["input_words"]),
         c_words("decode_input_words", cases["decode"]["input_words"]),
         c_words("gamma_words", gamma_words),
         c_words("onehot192_weight_words", weight),
         c_words("prefill_coeff_words", cases["prefill"]["coeff_words"]),
         c_words("decode_coeff_words", cases["decode"]["coeff_words"]),
         c_first16("prefill_q_first16", cases["prefill"]["q_first"]),
         c_first16("prefill_k_first16", cases["prefill"]["k_first"]),
         c_first16("decode_q_first16", cases["decode"]["q_first"]),
         c_first16("decode_k_first16", cases["decode"]["k_first"]),
         "#endif"]
(dest / "vectors.h").write_text("\n\n".join(parts) + "\n")
(dest / "vector_manifest.json").write_text(json.dumps({
    "checkpoint_revision": "93efa2f097d58c2a74874c7e644dbc9b0cee75a2",
    "projection": "offline one-hot 192x576 tile repeated three times for Q and once for K",
    "numeric": "RTL RMSNorm Q16 reduction model, BF16 identity GEMM, BF16 eager RoPE",
    "cases": {name: {"rows": case["rows"]} for name, case in cases.items()},
}, indent=2) + "\n")
print(dest / "vectors.h")
