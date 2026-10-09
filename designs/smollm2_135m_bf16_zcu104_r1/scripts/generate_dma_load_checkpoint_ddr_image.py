#!/usr/bin/env python3
"""Make a sparse 64-bit DDR image from pinned BF16 checkpoint samples."""
import argparse
import hashlib
from pathlib import Path

DESIGN = Path(__file__).resolve().parents[1]
REGIONS = (
    (0x1000, "golden/gemm_systolic_model/weight16.hex", 9216),
    (0x6000, "golden/gemm_model/prefill_activation.hex", 18432),
    (0x10000, "golden/gemm_model/decode_activation.hex", 576),
)


def read_bf16(path: Path, count: int) -> list[int]:
    values = [int(line, 16) for line in path.read_text().splitlines() if line]
    if len(values) != count or any(value < 0 or value > 0xFFFF for value in values):
        raise ValueError(f"invalid BF16 vector: {path}")
    return values


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    pinned = {}
    for line in (DESIGN / "board_smoke/source_vectors.sha256").read_text().splitlines():
        digest, name = line.split(maxsplit=1)
        pinned[name] = digest
    lines = []
    for address, source, count in REGIONS:
        path = DESIGN / source
        if hashlib.sha256(path.read_bytes()).hexdigest() != pinned[source]:
            raise ValueError(f"pinned checkpoint source changed: {path}")
        values = read_bf16(path, count)
        lines.append(f"@{address // 8:04x}")
        for i in range(0, count, 4):
            word = sum(values[i + lane] << (16 * lane) for lane in range(4))
            lines.append(f"{word:016x}")
    args.output.write_text("\n".join(lines) + "\n")
    print(f"DDR image: {args.output} ({sum(n * 2 for _, _, n in REGIONS)} input bytes)")


if __name__ == "__main__":
    main()
