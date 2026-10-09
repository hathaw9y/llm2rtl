#!/usr/bin/env python3
"""Board vectors: actual BF16 RMSNorm data and one-hot GEMM projection."""
from pathlib import Path

design = Path(__file__).resolve().parents[1]
gold = design / "golden" / "rmsnorm_checkpoint"
dest = design / "dma_rms_gemm_board_probe"
dest.mkdir(exist_ok=True)


def read_words(name):
    return [int(line, 16) for line in (gold / name).read_text().splitlines()]


def c_words(label, values):
    lines = [f"static const uint32_t {label}[{len(values)}][4] = {{"]
    for value in values:
        lines.append("    {" + ", ".join(
            f"0x{(value >> (32*i)) & 0xffffffff:08x}u" for i in range(4)
        ) + "},")
    return "\n".join(lines + ["};"])


input_words = read_words("prefill_input_words.hex")
decode_words = read_words("decode_input_words.hex")
gamma_words = read_words("gamma_words.hex")
expected_words = read_words("prefill_expected_words.hex")
decode_expected_words = read_words("decode_expected_words.hex")
weights = []
for n in range(16):
    for k_word in range(72):
        value = 0
        if k_word == n // 8:
            value = 0x3f80 << (16 * (n % 8))
        weights.append(value)
(gold / "onehot_weight_words.hex").write_text(
    "\n".join(f"{value:032x}" for value in weights) + "\n")
expected_first16 = []
for row in range(32):
    for word in expected_words[row*72:row*72 + 2]:
        expected_first16.extend((word >> (16*lane)) & 0xffff
                                for lane in range(8))
decode_expected_first16 = []
for word in decode_expected_words[:2]:
    decode_expected_first16.extend((word >> (16*lane)) & 0xffff
                                   for lane in range(8))
parts = ["#ifndef SMOLLM2_RMS_GEMM_BOARD_VECTORS_H",
         "#define SMOLLM2_RMS_GEMM_BOARD_VECTORS_H", "#include <stdint.h>",
         c_words("prefill_input_words", input_words),
         c_words("decode_input_words", decode_words),
         c_words("gamma_words", gamma_words),
         c_words("onehot_weight_words", weights),
         "static const uint16_t expected_first16[512] = {",
         *["    " + ", ".join(f"0x{v:04x}u" for v in expected_first16[i:i+16]) + ","
           for i in range(0, 512, 16)], "};",
         "static const uint16_t decode_expected_first16[16] = {",
         "    " + ", ".join(f"0x{v:04x}u" for v in decode_expected_first16) + ",",
         "};", "#endif"]
(dest / "vectors.h").write_text("\n\n".join(parts) + "\n")
print(dest / "vectors.h")
