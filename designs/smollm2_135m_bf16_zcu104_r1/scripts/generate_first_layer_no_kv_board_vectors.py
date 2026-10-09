#!/usr/bin/env python3
"""Freeze layer-0 ISA inputs and BF16 output for the ZCU104 baremetal probe."""
from __future__ import annotations

from pathlib import Path
import hashlib
import json
import sys

import torch
from transformers import AutoModelForCausalLM

DESIGN = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(DESIGN / "scripts"))
from check_first_layer_no_kv_isa_candidate import make_program, REVISION  # noqa: E402
sys.path.insert(0, str(DESIGN.parents[1] / "verification/prototypes"))
import smollm2_135m_isa_feasibility as isa  # noqa: E402

OUT = DESIGN / "first_layer_no_kv_board_probe"
OUT.mkdir(exist_ok=True)


def packed_words(value: torch.Tensor) -> list[int]:
    bits = value.contiguous().view(torch.uint16).reshape(-1).tolist()
    assert len(bits) % 8 == 0
    return [sum(int(bits[i + j]) << (16 * j) for j in range(8))
            for i in range(0, len(bits), 8)]


def c_words(name: str, words: list[int]) -> str:
    lines = [f"static const uint32_t {name}[{len(words)}][4] __attribute__((aligned(64))) = {{"]
    lines.extend("  {" + ",".join(f"0x{(v >> (32*j)) & 0xffffffff:08x}u"
                                  for j in range(4)) + "}," for v in words)
    return "\n".join(lines + ["};"])


torch.set_num_threads(4)
model = AutoModelForCausalLM.from_pretrained(
    str(isa.CHECKPOINT), local_files_only=True, dtype=torch.bfloat16,
    attn_implementation="eager").eval()
cases = {"prefill32": [(i * 17 + 11) % 49152 for i in range(32)],
         "single_token_cold": [11]}
weight_keys: list[tuple] = []
for tokens in cases.values():
    for chunk in make_program(tokens).chunks:
        for cmd in chunk:
            if cmd.op == "DMA_LOAD" and cmd.args[1][0] == "weight":
                key = cmd.args[1][1:]
                if key not in weight_keys:
                    weight_keys.append(key)
ddr = isa.DDR(model, cases["prefill32"])
weight_offsets = {}
weight_words = []
for key in weight_keys:
    weight_offsets[key] = len(weight_words)
    weight_words.extend(packed_words(ddr.weight[key]))

header = ["#ifndef SMOLLM2_FIRST_LAYER_NO_KV_VECTORS_H",
          "#define SMOLLM2_FIRST_LAYER_NO_KV_VECTORS_H", "#include <stdint.h>",
          "typedef struct { uint32_t word[4]; uint32_t source; uint32_t offset_words; } isa_record_spec;",
          c_words("weight_words", weight_words)]
manifest = {"checkpoint_revision": REVISION,
            "checkpoint_file_sha256": hashlib.sha256((isa.CHECKPOINT / "model.safetensors").read_bytes()).hexdigest(),
            "scope": "first layer, contiguous positions from zero, no KV cache",
            "weight_words": len(weight_words), "cases": {}}

for case_index, (name, tokens) in enumerate(cases.items()):
    rows = len(tokens)
    embedding = torch.stack([ddr.embedding[token] for token in tokens])
    coeff = torch.cat((ddr.rope["cos"][:rows], ddr.rope["sin"][:rows]), dim=-1)
    header.append(c_words(f"{name}_embedding_words", packed_words(embedding)))
    header.append(c_words(f"{name}_coeff_words", packed_words(coeff)))
    captured = []
    hook = model.model.layers[0].register_forward_hook(
        lambda _module, _args, output: captured.append(output.detach().cpu().clone()))
    with torch.inference_mode():
        model(torch.tensor([tokens]), use_cache=True, logits_to_keep=1)
    hook.remove()
    expected = captured[0][0, :, :16].contiguous().view(torch.uint16).reshape(-1).tolist()
    header.append(f"static const uint16_t {name}_expected_first16[{len(expected)}] = {{" +
                  ",".join(f"0x{int(v):04x}u" for v in expected) + "};")
    entries = []
    for chunk in make_program(tokens).chunks:
        for cmd in chunk:
            record = isa.wire_record(cmd, ddr)
            source, offset_words = 0xffffffff, 0
            if cmd.op == "DMA_LOAD":
                key = cmd.args[1]
                if key[0] == "embedding":
                    source, offset_words = case_index * 2, cmd.args[2] * 72
                elif key[0] == "rope":
                    source, offset_words = case_index * 2 + 1, 0
                else:
                    source, offset_words = 4, weight_offsets[key[1:]]
                record &= ~(((1 << 32) - 1) << 25)
            words = [(record >> (32 * i)) & 0xffffffff for i in range(4)]
            entries.append("  {{" + ",".join(f"0x{v:08x}u" for v in words) +
                           f"}}, {source}u, {offset_words}u}},")
    header.append(f"static const isa_record_spec {name}_program[{len(entries)}] = {{\n" +
                  "\n".join(entries) + "\n};")
    manifest["cases"][name] = {"tokens": tokens, "rows": rows,
                                "program_records": len(entries),
                                "chunks": (len(entries) + 15) // 16,
                                "compared_values": len(expected)}
header.append("#endif")
(OUT / "vectors.h").write_text("\n\n".join(header) + "\n")
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(f"{OUT / 'vectors.h'} weight_words={len(weight_words)}")
