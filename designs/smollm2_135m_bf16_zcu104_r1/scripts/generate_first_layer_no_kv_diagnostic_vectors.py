#!/usr/bin/env python3
"""Reference tap values for localizing a board first-layer mismatch."""
from pathlib import Path
import sys

import torch
from transformers import AutoModelForCausalLM
from transformers.models.llama.modeling_llama import apply_rotary_pos_emb

DESIGN = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(DESIGN.parents[1] / "verification/prototypes"))
import smollm2_135m_isa_feasibility as isa  # noqa: E402

OUT = DESIGN / "first_layer_no_kv_board_probe/diagnostic_vectors.h"
FULL_OUT = DESIGN / "first_layer_full_output_board_probe/full_output_vectors.h"
STAGE_OUT = DESIGN / "first_layer_stage_board_probe/stage_vectors.h"
FFN_OUT = DESIGN / "first_layer_ffn_board_probe/ffn_vectors.h"
torch.set_num_threads(4)
model = AutoModelForCausalLM.from_pretrained(
    str(isa.CHECKPOINT), local_files_only=True, dtype=torch.bfloat16,
    attn_implementation="eager").eval()
header = ["#ifndef SMOLLM2_FIRST_LAYER_DIAGNOSTIC_VECTORS_H",
          "#define SMOLLM2_FIRST_LAYER_DIAGNOSTIC_VECTORS_H", "#include <stdint.h>"]
full_header = ["#ifndef SMOLLM2_FIRST_LAYER_FULL_OUTPUT_VECTORS_H",
               "#define SMOLLM2_FIRST_LAYER_FULL_OUTPUT_VECTORS_H", "#include <stdint.h>"]
stage_header = ["#ifndef SMOLLM2_FIRST_LAYER_STAGE_VECTORS_H",
                "#define SMOLLM2_FIRST_LAYER_STAGE_VECTORS_H", "#include <stdint.h>"]
ffn_header = ["#ifndef SMOLLM2_FIRST_LAYER_FFN_VECTORS_H",
              "#define SMOLLM2_FIRST_LAYER_FFN_VECTORS_H", "#include <stdint.h>"]


def emit(name: str, value: torch.Tensor, rows: int):
    value = value.reshape(rows, -1)[:, :16].contiguous()
    bits = value.view(torch.uint16).reshape(-1).tolist()
    header.append(f"static const uint16_t {name}[{len(bits)}] = {{" +
                  ",".join(f"0x{int(v):04x}u" for v in bits) + "};")


for case, tokens in (("prefill32", [(i * 17 + 11) % 49152 for i in range(32)]),
                     ("single_token_cold", [11])):
    rows = len(tokens)
    captured = {}
    hooks = isa.install_reference_hooks(model, captured)
    with torch.inference_mode():
        model(torch.tensor([tokens]), use_cache=True, logits_to_keep=1)
    for hook in hooks:
        hook.remove()
    input_norm = captured[0, "input_layernorm"]
    q = captured[0, "q_proj"].reshape(1, rows, 9, 64).transpose(1, 2)
    k = captured[0, "k_proj"].reshape(1, rows, 3, 64).transpose(1, 2)
    cos, sin = model.model.rotary_emb(input_norm, torch.arange(rows)[None, :])
    q_rot, k_rot = apply_rotary_pos_emb(q, k, cos, sin)
    score = (q_rot[0, 0].float() @ k_rot[0, 0].float().T) / 8.0
    score = score.to(torch.bfloat16)
    score = torch.tril(score)
    score_padded = torch.zeros((rows, max(16, rows)), dtype=torch.bfloat16)
    score_padded[:, :rows] = score
    prob = captured[0, "attn_weights"][0, 0]
    prob_padded = torch.zeros_like(score_padded)
    prob_padded[:, :rows] = prob
    values = {
        "input_norm": input_norm,
        "q_rope": q_rot[0].transpose(0, 1).contiguous().reshape(rows, 576),
        "k_rope": k_rot[0].transpose(0, 1).contiguous().reshape(rows, 192),
        "score": score_padded,
        "prob": prob_padded,
        "context": captured[0, "o_proj_input"],
        "attention_residual": captured[0, "post_attention_layernorm_input"],
        "post_norm": captured[0, "post_attention_layernorm"],
        "silu": captured[0, "down_proj_input"],
        "final": captured[0, "layer_output"],
    }
    for stage, value in values.items():
        emit(f"{case}_{stage}_first16", value, rows)
    final_bits = values["final"].reshape(rows, 576).contiguous().view(torch.uint16).reshape(-1).tolist()
    full_header.append(f"static const uint16_t {case}_expected_full[{len(final_bits)}] = {{" +
                       ",".join(f"0x{int(v):04x}u" for v in final_bits) + "};")
    for stage, value in (("attention_residual", values["attention_residual"]),
                         ("down_projection", captured[0, "down_proj"])):
        bits = value.reshape(rows, 576).contiguous().view(torch.uint16).reshape(-1).tolist()
        stage_header.append(f"static const uint16_t {case}_{stage}_full[{len(bits)}] = {{" +
                            ",".join(f"0x{int(v):04x}u" for v in bits) + "};")
    for stage, value in (("post_norm", values["post_norm"]),
                         ("gate_projection", captured[0, "gate_proj"]),
                         ("up_projection", captured[0, "up_proj"]),
                         ("silu_mul", values["silu"])):
        bits = value.reshape(rows, -1).contiguous().view(torch.uint16).reshape(-1).tolist()
        ffn_header.append(f"static const uint16_t {case}_{stage}_full[{len(bits)}] = {{" +
                          ",".join(f"0x{int(v):04x}u" for v in bits) + "};")
header.append("#endif")
OUT.write_text("\n\n".join(header) + "\n")
full_header.append("#endif")
stage_header.append("#endif")
ffn_header.append("#endif")
FULL_OUT.parent.mkdir(parents=True, exist_ok=True)
FULL_OUT.write_text("\n\n".join(full_header) + "\n")
STAGE_OUT.parent.mkdir(parents=True, exist_ok=True)
STAGE_OUT.write_text("\n\n".join(stage_header) + "\n")
FFN_OUT.parent.mkdir(parents=True, exist_ok=True)
FFN_OUT.write_text("\n\n".join(ffn_header) + "\n")
print(OUT)
print(FULL_OUT)
print(STAGE_OUT)
print(FFN_OUT)
