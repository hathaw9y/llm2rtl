#!/usr/bin/env python3
"""Pin layer-0 o_proj, attention output, and residual from the HF checkpoint."""
import hashlib
import json
from pathlib import Path

import torch
from transformers import AutoModelForCausalLM

design = Path(__file__).resolve().parents[1]
revision = "93efa2f097d58c2a74874c7e644dbc9b0cee75a2"
checkpoint = (Path.home() / ".cache/huggingface/hub/models--HuggingFaceTB--SmolLM2-135M"
              / "snapshots" / revision)
gold = design / "golden/first_layer_attention_output"
gold.mkdir(parents=True, exist_ok=True)
board = design / "first_layer_attention_output_board_probe"
board.mkdir(exist_ok=True)


def read_words(path, rows):
    words = [int(line, 16) for line in path.read_text().split()]
    assert len(words) == rows * 72
    bits = [(word >> (16 * lane)) & 0xffff for word in words for lane in range(8)]
    return torch.tensor(bits, dtype=torch.uint16).view(torch.bfloat16).reshape(rows, 576)


def write_words(path, tensor):
    bits = tensor.contiguous().view(torch.uint16).reshape(-1).tolist()
    assert len(bits) % 8 == 0
    words = [sum(bits[i + lane] << (16 * lane) for lane in range(8))
             for i in range(0, len(bits), 8)]
    path.write_text("".join(f"{word:032x}\n" for word in words))
    return words


def c_words(name, words):
    lines = [f"static const uint32_t {name}[{len(words)}][4] = {{"]
    lines += ["    {" + ", ".join(f"0x{(word >> (32 * i)) & 0xffffffff:08x}u"
                                  for i in range(4)) + "}," for word in words]
    return "\n".join(lines + ["};"])


def c_first16(name, tensor):
    bits = tensor[:, :16].contiguous().view(torch.uint16).reshape(-1).tolist()
    lines = [f"static const uint16_t {name}[{len(bits)}] = {{"]
    lines += ["    " + ", ".join(f"0x{x:04x}u" for x in bits[i:i+16]) + ","
              for i in range(0, len(bits), 16)]
    return "\n".join(lines + ["};"])


torch.set_num_threads(4)
model = AutoModelForCausalLM.from_pretrained(
    str(checkpoint), local_files_only=True, dtype=torch.bfloat16,
    attn_implementation="eager").eval()
layer = model.model.layers[0]
attn_output = []
residual_input = []
hook_attn = layer.self_attn.register_forward_hook(
    lambda _module, _args, result:
    attn_output.append(result[0].detach().cpu().reshape(-1, 576).clone()))
hook_input = layer.input_layernorm.register_forward_hook(
    lambda _module, args, _result:
    residual_input.append(args[0].detach().cpu().reshape(-1, 576).clone()))
tokens = [(i * 17 + 11) % 49152 for i in range(33)]
with torch.inference_mode():
    prefill = model(torch.tensor([tokens[:32]]), use_cache=True, logits_to_keep=1)
    model(torch.tensor([[tokens[32]]]), past_key_values=prefill.past_key_values,
          use_cache=True, logits_to_keep=1)
hook_attn.remove()
hook_input.remove()

weight = layer.self_attn.o_proj.weight.detach().cpu().contiguous()
assert tuple(weight.shape) == (576, 576)
weight_words = write_words(gold / "o_weight_tiles_words.hex", weight)
assert len(weight_words) == 41472
header = ["#ifndef SMOLLM2_FIRST_LAYER_ATTN_OUTPUT_VECTORS_H",
          "#define SMOLLM2_FIRST_LAYER_ATTN_OUTPUT_VECTORS_H",
          "#include <stdint.h>", c_words("o_weight_words", weight_words)]
manifest = {
    "checkpoint_revision": revision,
    "checkpoint_file_sha256": hashlib.sha256((checkpoint / "model.safetensors").read_bytes()).hexdigest(),
    "tokens": tokens,
    "reference": "transformers eager BF16 self_attn output after o_proj; decoder residual is BF16 input + self_attn output",
    "weight_layout": "three output-column tiles, each [192,576] BF16 in N,K order",
    "cases": {},
}
for case, rows, index in (("prefill32", 32, 0), ("decode1", 1, 1)):
    context = read_words(design / "golden/attention_checkpoint" /
                         f"{case}_context_words.hex", rows)
    with torch.inference_mode():
        projected = layer.self_attn.o_proj(context).detach().cpu()
    assert torch.equal(projected, attn_output[index]), (
        case, "pinned attention context differs from HF self_attn output")
    residual = residual_input[index] + attn_output[index]
    assert torch.equal(residual_input[index], read_words(
        design / "golden/rmsnorm_checkpoint" /
        ("prefill_input_words.hex" if rows == 32 else "decode_input_words.hex"),
        rows))
    write_words(gold / f"{case}_projected_words.hex", attn_output[index])
    write_words(gold / f"{case}_residual_words.hex", residual)
    header += [c_first16(f"{case}_projected_first16", attn_output[index]),
               c_first16(f"{case}_residual_first16", residual)]
    manifest["cases"][case] = {
        "rows": rows, "elements": rows * 576,
        "board_compared_elements_per_output": rows * 16,
        "context_projection_matches_hf_bitwise": True,
    }
header.append("#endif")
(board / "vectors.h").write_text("\n\n".join(header) + "\n")
(gold / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(gold)
