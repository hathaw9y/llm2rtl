"""Independent packed-nibble oracle; this defines opaque test data, not quantization."""
import json
from pathlib import Path


def packed_word(stripe, row, width=128):
    elements = [(stripe * 3 + row * 5 + n + 7 * (n // 16)) % 16 for n in range(width // 4)]
    data = sum(value << (4 * n) for n, value in enumerate(elements))
    return data, elements


def generate(directory, ports=4, depth=16, width=128):
    out = Path(directory)
    out.mkdir(parents=True, exist_ok=True)
    words = []
    for row in range(depth):
        for stripe in range(ports):
            data, elements = packed_word(stripe, row, width)
            assert [(data >> (4 * n)) & 15 for n in range(width // 4)] == elements
            if width == 128: assert (data & ((1 << 64) - 1)) != (data >> 64)
            words.append({"row": row, "stripe": stripe, "hex": f"{data:0{width//4}x}", "nibbles_low_first": elements})
    (out / "packed_nibble_vectors.json").write_text(json.dumps(words, indent=2) + "\n")
    report = {"kind": "opaque_storage_nibble_round_trip", "quantization_policy": None,
              "words": len(words), "elements_per_word": width // 4, "round_trip_passed": True,
              "memory_reference": "SystemVerilog TB byte array, sampling before masked writes",
              "not_claimed": ["numeric quantization", "real checkpoint layout compatibility"]}
    (out / "golden_reference_report.json").write_text(json.dumps(report, indent=2) + "\n")
    return report
