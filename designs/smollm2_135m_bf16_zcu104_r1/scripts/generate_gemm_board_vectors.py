#!/usr/bin/env python3
"""Pack pinned checkpoint BF16 samples for a PS data-transfer-only test."""
import hashlib
from pathlib import Path

design = Path(__file__).resolve().parents[1]
source = design / "golden"
target_dir = design / "board_smoke"
target_dir.mkdir(exist_ok=True)


def read_hex(path):
    return [int(line.strip(), 16) for line in path.read_text().splitlines()
            if line.strip()]


def packed_words(values):
    assert len(values) % 8 == 0
    for index in range(0, len(values), 8):
        yield [sum(values[index + 2 * word + lane] << (16 * lane)
                   for lane in range(2)) for word in range(4)]


def write_words(name, path, expected_count):
    values = read_hex(path)
    assert len(values) == expected_count and all(0 <= x < 65536 for x in values)
    lines = [f"static const uint32_t {name}[{len(values)//8}][4] = {{"]
    for words in packed_words(values):
        lines.append("    {" + ", ".join(f"0x{x:08x}u" for x in words) + "},")
    lines.append("};")
    return "\n".join(lines), hashlib.sha256(path.read_bytes()).hexdigest()


def write_golden(name, path, expected_count):
    values = read_hex(path)
    assert len(values) == expected_count
    lines = [f"static const uint16_t {name}[{len(values)}] = {{"]
    for index in range(0, len(values), 12):
        lines.append("    " + ", ".join(f"0x{x:04x}u" for x in values[index:index+12]) + ",")
    lines.append("};")
    return "\n".join(lines), hashlib.sha256(path.read_bytes()).hexdigest()


items = [
    (write_words, "prefill_activation_words", source / "gemm_model/prefill_activation.hex", 18432),
    (write_words, "decode_activation_words", source / "gemm_model/decode_activation.hex", 576),
    (write_words, "q_proj_weight_words", source / "gemm_systolic_model/weight16.hex", 9216),
    (write_golden, "prefill_expected", source / "gemm_systolic_model/prefill32_exact16.hex", 512),
    (write_golden, "decode_expected", source / "gemm_systolic_model/decode_exact16.hex", 16),
]
parts = ["#ifndef SMOLLM2_GEMM_BOARD_VECTORS_H",
         "#define SMOLLM2_GEMM_BOARD_VECTORS_H", "#include <stdint.h>"]
hashes = []
for writer, name, path, count in items:
    block, digest = writer(name, path, count)
    parts.append(block)
    hashes.append(f"{digest}  {path.relative_to(design)}")
parts.append("#endif")
(target_dir / "vectors.h").write_text("\n\n".join(parts) + "\n")
(target_dir / "source_vectors.sha256").write_text("\n".join(hashes) + "\n")
print(target_dir / "vectors.h")
