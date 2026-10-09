#!/usr/bin/env python3
"""Package pinned score words and first-head golden for the Softmax board probe."""
from pathlib import Path

design = Path(__file__).resolve().parents[1]
gold = design / "golden/softmax_checkpoint"
dest = design / "dma_rms_gemm_rope_softmax_board_probe"
dest.mkdir(exist_ok=True)
(dest / "vectors.h").write_bytes(
    (design / "dma_rms_gemm_rope_board_probe/vectors.h").read_bytes())


def words(label):
    return [int(line, 16) for line in (gold / f"{label}_words.hex").read_text().splitlines()]


def c_words(label, values):
    lines = [f"static const uint32_t {label}[{len(values)}][4] = {{"]
    for value in values:
        lines.append("    {" + ", ".join(
            f"0x{(value >> (32*i)) & 0xffffffff:08x}u" for i in range(4)
        ) + "},")
    return "\n".join(lines + ["};"])


def c_first16(label, values):
    lines = [f"static const uint16_t {label}[{len(values)}] = {{"]
    for i in range(0, len(values), 16):
        lines.append("    " + ", ".join(
            f"0x{v:04x}u" for v in values[i:i+16]) + ",")
    return "\n".join(lines + ["};"])


parts = ["#ifndef SMOLLM2_SOFTMAX_BOARD_VECTORS_H",
         "#define SMOLLM2_SOFTMAX_BOARD_VECTORS_H", "#include <stdint.h>"]
for label, rows, head_words in (("prefill32", 32, 4), ("decode1", 1, 5)):
    score = words(f"{label}_score")
    expected = words(f"{label}_expected")
    parts.append(c_words(f"{label}_score_words", score))
    first = []
    for row in range(rows):
        for word in expected[row*9*head_words:row*9*head_words+2]:
            first.extend((word >> (16*lane)) & 0xffff for lane in range(8))
    parts.append(c_first16(f"{label}_softmax_first16", first))
parts.append("#endif")
(dest / "softmax_vectors.h").write_text("\n\n".join(parts) + "\n")
print(dest / "softmax_vectors.h")
