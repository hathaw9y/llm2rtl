#!/usr/bin/env python3
"""Independent float64/RNE golden vectors for 576-wide BF16 residual ADD."""
from pathlib import Path
import json
import math
import random
import struct

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "golden/add_checkpoint"
OUT.mkdir(exist_ok=True)
rng = random.Random(0x135ADD)


def bf16_to_float(bits):
    return struct.unpack(">f", struct.pack(">I", bits << 16))[0]


def float_to_bf16(value):
    try:
        bits = struct.unpack(">I", struct.pack(">f", value))[0]
    except OverflowError:
        return 0xff80 if math.copysign(1.0, value) < 0 else 0x7f80
    upper = bits >> 16
    lower = bits & 0xFFFF
    return (upper + (lower > 0x8000 or
                     (lower == 0x8000 and (upper & 1)))) & 0xFFFF


def read_words(path):
    return [int(line.strip(), 16) for line in path.read_text().splitlines()]


def write_words(path, values):
    path.write_text("".join(f"{word:032x}\n" for word in values))


def create(phase, count):
    src = read_words(ROOT / f"golden/rmsnorm_checkpoint/{phase}_input_words.hex")
    assert len(src) == count * 72
    right, expected = [], []
    directed = [0x0000, 0x8000, 0x3f80, 0xbf80,
                0x3f00, 0x4000, 0x0080, 0x0001]
    for index, word in enumerate(src):
        right_word = 0
        expected_word = 0
        for lane in range(8):
            a = (word >> (16 * lane)) & 0xFFFF
            if index == 0:
                b = directed[lane]
            else:
                b = float_to_bf16(rng.uniform(-2.0, 2.0))
            got = float_to_bf16(bf16_to_float(a) + bf16_to_float(b))
            right_word |= b << (16 * lane)
            expected_word |= got << (16 * lane)
        right.append(right_word)
        expected.append(expected_word)
    write_words(OUT / f"{phase}_left_words.hex", src)
    write_words(OUT / f"{phase}_right_words.hex", right)
    write_words(OUT / f"{phase}_expected_words.hex", expected)
    context = read_words(ROOT / "golden/attention_checkpoint" /
                         ("decode1_context_words.hex" if phase == "decode"
                          else "prefill32_context_words.hex"))
    assert len(context) == len(src)
    residual = []
    for left_word, context_word in zip(src, context):
        result = 0
        for lane in range(8):
            a = (left_word >> (16 * lane)) & 0xFFFF
            b = (context_word >> (16 * lane)) & 0xFFFF
            result |= float_to_bf16(bf16_to_float(a) +
                                    bf16_to_float(b)) << (16 * lane)
        residual.append(result)
    write_words(OUT / f"{phase}_residual_expected_words.hex", residual)
    return {
        "rows": count,
        "elements": count * 576,
        "left_source": f"golden/rmsnorm_checkpoint/{phase}_input_words.hex",
        "right_source": "deterministic BF16 values; seed 0x135ADD",
        "reference": "binary64 sum of two exactly represented BF16 operands, rounded to BF16 nearest-even",
        "identity_projection_probe": "context from pinned checkpoint is used as ADD right operand after identity GEMM in PL",
    }


def create_edge():
    cases = [
        (0x3f80, 0x3b80), (0x3f80, 0x3b81),
        (0x3f81, 0x3b80), (0xbf80, 0x3f80),
        (0x0001, 0x0001), (0x007f, 0x0001),
        (0x0080, 0x807f), (0x8000, 0x8000),
        (0x7f7f, 0x7f7f), (0x3f80, 0x0001),
        (0x3f80, 0x8001), (0x0001, 0x8001),
    ]
    left, right, expected = [], [], []
    for word_index in range(72):
        a_word = b_word = result_word = 0
        for lane in range(8):
            a, b = cases[(word_index*8+lane) % len(cases)]
            a_word |= a << (16*lane)
            b_word |= b << (16*lane)
            result_word |= float_to_bf16(bf16_to_float(a) +
                                         bf16_to_float(b)) << (16*lane)
        left.append(a_word); right.append(b_word); expected.append(result_word)
    for name, words in (("left", left), ("right", right),
                        ("expected", expected)):
        write_words(OUT / f"edge_{name}_words.hex", words)
    return {"rows": 1, "elements": 576, "cases": len(cases),
            "reference": "directed BF16 ties, cancellation, subnormals and overflow"}


manifest = {
    "prefill": create("prefill", 32),
    "decode": create("decode", 1),
    "edge": create_edge(),
}
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
header = ["#ifndef SMOLLM2_ADD_BOARD_VECTORS_H",
          "#define SMOLLM2_ADD_BOARD_VECTORS_H", "#include <stdint.h>"]
for phase, count in (("prefill", 32), ("decode", 1)):
    words = read_words(OUT / f"{phase}_residual_expected_words.hex")
    values = [((words[row*72 + col//8] >> (16*(col%8))) & 0xFFFF)
              for row in range(count) for col in range(16)]
    name = f"{phase}_add_first16"
    header.append(f"static const uint16_t {name}[{len(values)}] = {{")
    for start in range(0, len(values), 16):
        header.append("  " + ", ".join(f"0x{value:04x}" for value in
                                     values[start:start+16]) + ",")
    header.append("};")
header.append("#endif")
(ROOT / "dma_rms_gemm_rope_attention_add_board_probe/add_vectors.h").write_text(
    "\n".join(header) + "\n")
