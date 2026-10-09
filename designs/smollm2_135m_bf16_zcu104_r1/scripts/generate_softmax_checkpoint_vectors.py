#!/usr/bin/env python3
"""Pin first-layer BF16 attention scores and FP32-softmax/BF16 golden."""
import json
import math
from pathlib import Path

import torch

design = Path(__file__).resolve().parents[1]
source = design / "golden/rope_checkpoint"
dest = design / "golden/softmax_checkpoint"
dest.mkdir(exist_ok=True)


def read_rope(case, name, rows, heads):
    words = [int(x, 16) for x in (source / case / f"{name}_expected_words.hex").read_text().split()]
    bits = [(value >> (16 * lane)) & 0xffff for value in words for lane in range(8)]
    return (torch.tensor(bits, dtype=torch.uint16).view(torch.bfloat16)
            .reshape(rows, heads, 64).transpose(0, 1).contiguous())


def save_words(path, values):
    bits = values.contiguous().view(torch.uint16).reshape(-1).tolist()
    assert len(bits) % 8 == 0
    path.write_text("\n".join(
        f"{sum(bits[i+j] << (16*j) for j in range(8)):032x}"
        for i in range(0, len(bits), 8)) + "\n")


q = read_rope("prefill", "q", 32, 9)
k = read_rope("prefill", "k", 32, 3).repeat_interleave(3, 0)
qd = read_rope("decode", "q", 1, 9)
kd = read_rope("decode", "k", 1, 3).repeat_interleave(3, 0)
prefill_score = torch.matmul(q, k.transpose(1, 2)) * 0.125
decode_score = torch.matmul(qd, torch.cat((k, kd), 1).transpose(1, 2)) * 0.125
long_columns = torch.arange(1024, dtype=torch.float32)
long_score = torch.stack([
    (torch.sin(long_columns * (0.007 + head * 0.0003)) * 3.0 +
     torch.cos(long_columns * 0.019 + head) * 0.75).to(torch.bfloat16)
    for head in range(9)
])[:, None, :]

manifest = {
    "checkpoint_revision": "93efa2f097d58c2a74874c7e644dbc9b0cee75a2",
    "numeric": "BF16 score; FP32 stable causal softmax; BF16 round-to-nearest-even output",
    "layout": "[row,9,ceil(kv_len/8)] 128-bit words, eight BF16 lanes per word",
    "cases": {},
}
for name, score, query_start in (
    ("prefill32", prefill_score, 0),
    ("decode1", decode_score, 32),
    ("context1024", long_score, 1023),
):
    heads, rows, kv_len = score.shape
    assert heads == 9
    padded = math.ceil(kv_len / 8) * 8
    valid = torch.arange(kv_len)[None, None, :] <= (
        query_start + torch.arange(rows)[None, :, None])
    masked = score.float().masked_fill(~valid, -float("inf"))
    expected = torch.softmax(masked, dim=-1).to(torch.bfloat16)
    score_rows = score.permute(1, 0, 2).contiguous()
    out_rows = expected.permute(1, 0, 2).contiguous()
    if padded != kv_len:
        score_rows = torch.nn.functional.pad(score_rows, (0, padded-kv_len), value=float("inf"))
        out_rows = torch.nn.functional.pad(out_rows, (0, padded-kv_len), value=0)
    save_words(dest / f"{name}_score_words.hex", score_rows)
    save_words(dest / f"{name}_expected_words.hex", out_rows)
    manifest["cases"][name] = {
        "query_start": query_start, "m_count": rows, "kv_len": kv_len,
        "padded_len": padded, "word_count": rows * 9 * (padded // 8),
        "source": "checkpoint first-layer Q/K RoPE" if name != "context1024" else "synthetic maximum-context score",
    }
(dest / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(dest)
