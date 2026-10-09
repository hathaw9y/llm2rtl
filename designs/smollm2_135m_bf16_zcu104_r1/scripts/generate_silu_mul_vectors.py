#!/usr/bin/env python3
"""Pin BF16 SiLU lookup and layer-0 FFN operands from the checkpoint."""
import hashlib
import json
from pathlib import Path

import torch
from transformers import AutoModelForCausalLM

design = Path(__file__).resolve().parents[1]
revision = "93efa2f097d58c2a74874c7e644dbc9b0cee75a2"
checkpoint = (Path.home() / ".cache/huggingface/hub/models--HuggingFaceTB--SmolLM2-135M"
              / "snapshots" / revision)
gold = design / "golden/silu_mul_checkpoint"
gold.mkdir(parents=True, exist_ok=True)
board = design / "silu_mul_board_probe"
board.mkdir(exist_ok=True)


def pack_words(tensor):
    bits = tensor.contiguous().view(torch.uint16).reshape(-1).tolist()
    assert len(bits) % 8 == 0
    return [sum(bits[i + lane] << (16 * lane) for lane in range(8))
            for i in range(0, len(bits), 8)]


def write_words(path, tensor):
    words = pack_words(tensor)
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
    lines += ["    " + ", ".join(f"0x{x:04x}u" for x in bits[i:i + 16]) + ","
              for i in range(0, len(bits), 16)]
    return "\n".join(lines + ["};"])


torch.set_num_threads(4)
bits = torch.arange(65536, dtype=torch.int32).to(torch.uint16)
with torch.inference_mode():
    silu = torch.nn.functional.silu(bits.view(torch.bfloat16))
silu_bits = silu.view(torch.uint16).tolist()
for i in range(65536):
    if (i & 0x7f80) == 0x7f80:
        silu_bits[i] = 0
lut_path = design / "rtl/smollm2_silu_bf16_lut.mem"
lut_path.write_text("".join(f"{value:04x}\n" for value in silu_bits))

model = AutoModelForCausalLM.from_pretrained(
    str(checkpoint), local_files_only=True, dtype=torch.bfloat16,
    attn_implementation="eager").eval()
mlp = model.model.layers[0].mlp
captures = {"gate": [], "up": [], "product": []}
gate_hook = mlp.gate_proj.register_forward_hook(
    lambda _m, _a, output: captures["gate"].append(
        output.detach().cpu().reshape(-1, 1536).clone()))
up_hook = mlp.up_proj.register_forward_hook(
    lambda _m, _a, output: captures["up"].append(
        output.detach().cpu().reshape(-1, 1536).clone()))
product_hook = mlp.down_proj.register_forward_pre_hook(
    lambda _m, args: captures["product"].append(
        args[0].detach().cpu().reshape(-1, 1536).clone()))
tokens = [(i * 17 + 11) % 49152 for i in range(33)]
with torch.inference_mode():
    prefill = model(torch.tensor([tokens[:32]]), use_cache=True, logits_to_keep=1)
    model(torch.tensor([[tokens[32]]]), past_key_values=prefill.past_key_values,
          use_cache=True, logits_to_keep=1)
for hook in (gate_hook, up_hook, product_hook):
    hook.remove()

header = ["#ifndef SMOLLM2_SILU_MUL_BOARD_VECTORS_H",
          "#define SMOLLM2_SILU_MUL_BOARD_VECTORS_H", "#include <stdint.h>"]
manifest = {
    "checkpoint_revision": revision,
    "checkpoint_file_sha256": hashlib.sha256((checkpoint / "model.safetensors").read_bytes()).hexdigest(),
    "tokens": tokens,
    "reference": "HF eager BF16 gate/up projections, BF16 SiLU(gate), BF16 multiplication with up",
    "lut": {"entries": 65536, "word_bits": 16,
            "nonfinite_inputs": "executor error; ROM entries set to zero"},
    "cases": {},
}
for case, rows, index in (("prefill32", 32, 0), ("decode1", 1, 1)):
    gate = captures["gate"][index]
    up = captures["up"][index]
    expected = captures["product"][index]
    assert tuple(gate.shape) == tuple(up.shape) == tuple(expected.shape) == (rows, 1536)
    assert torch.equal(torch.nn.functional.silu(gate) * up, expected)
    for label, tensor in (("gate", gate), ("up", up), ("expected", expected)):
        words = write_words(gold / f"{case}_{label}_words.hex", tensor)
        if label != "expected":
            header.append(c_words(f"{case}_{label}_words", words))
    header.append(c_first16(f"{case}_expected_first16", expected))
    manifest["cases"][case] = {"rows": rows, "elements": rows * 1536,
                               "words_per_tensor": rows * 192,
                               "board_compared_elements": rows * 16}
edge_pairs = [
    (0x0000, 0x3f80), (0x8000, 0xbf80), (0x3f80, 0x3f80),
    (0xbf80, 0x3f80), (0x4000, 0xbf80), (0xc000, 0x4000),
    (0x0001, 0x3f80), (0x007f, 0x3f80), (0x0080, 0x0001),
    (0x7f7f, 0x3f80), (0xff7f, 0x3f80), (0x3f80, 0x7f7f),
    (0x3f00, 0x3f00), (0x4040, 0x3e80), (0xc0c0, 0x3f80),
]
edge_gate_bits = [edge_pairs[i % len(edge_pairs)][0] for i in range(1536)]
edge_up_bits = [edge_pairs[i % len(edge_pairs)][1] for i in range(1536)]
edge_gate = torch.tensor(edge_gate_bits, dtype=torch.uint16).view(torch.bfloat16)
edge_up = torch.tensor(edge_up_bits, dtype=torch.uint16).view(torch.bfloat16)
edge_expected = torch.nn.functional.silu(edge_gate) * edge_up
for label, tensor in (("gate", edge_gate), ("up", edge_up),
                      ("expected", edge_expected)):
    write_words(gold / f"edge_{label}_words.hex", tensor)
manifest["cases"]["edge"] = {"rows": 1, "elements": 1536,
                             "directed_pairs": len(edge_pairs)}
header.append("#endif")
(board / "vectors.h").write_text("\n\n".join(header) + "\n")
(gold / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(gold)
