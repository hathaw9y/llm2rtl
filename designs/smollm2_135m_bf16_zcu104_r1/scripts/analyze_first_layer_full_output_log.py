#!/usr/bin/env python3
"""Compare every BF16 first-layer B0 value printed by the ZCU104 probe."""
from pathlib import Path
import argparse
import json
import math
import re
import struct

DESIGN = Path(__file__).resolve().parents[1]
REFERENCE = DESIGN / "first_layer_full_output_board_probe/full_output_vectors.h"


def bf16(bits: int) -> float:
    return struct.unpack("<f", struct.pack("<I", bits << 16))[0]


def ordered(bits: int) -> int:
    return 0xffff - bits if bits & 0x8000 else bits + 0x8000


def reference(name: str) -> list[int]:
    source = REFERENCE.read_text()
    match = re.search(rf"static const uint16_t {name}_expected_full\[\d+\] = \{{(.*?)\}};",
                      source, re.S)
    if not match:
        raise ValueError(f"reference {name} missing")
    return [int(word, 16) for word in re.findall(r"0x([0-9a-fA-F]{4})u", match[1])]


def analyze(actual: list[int], expected: list[int], rows: int) -> dict:
    if len(actual) != len(expected) or len(actual) != rows * 576:
        raise ValueError("output/reference length mismatch")
    errors = []
    for index, (a, e) in enumerate(zip(actual, expected)):
        av, ev = bf16(a), bf16(e)
        if not math.isfinite(av) or not math.isfinite(ev):
            raise ValueError(f"nonfinite output at {index}")
        errors.append({"row": index // 576, "col": index % 576,
                       "actual_hex": f"{a:04X}", "expected_hex": f"{e:04X}",
                       "actual": av, "expected": ev, "abs": abs(av - ev),
                       "ulp": abs(ordered(a) - ordered(e))})
    count = len(errors)
    mse = sum(x["abs"] ** 2 for x in errors) / count
    ref_mse = sum(x["expected"] ** 2 for x in errors) / count
    return {"values": count,
            "mean_abs": sum(x["abs"] for x in errors) / count,
            "rmse": math.sqrt(mse),
            "reference_rms": math.sqrt(ref_mse),
            "normalized_rmse": math.sqrt(mse / ref_mse),
            "max_abs": max(x["abs"] for x in errors),
            "max_ulp": max(x["ulp"] for x in errors),
            "legacy_failures": sum(x["ulp"] > 16 and x["abs"] > 0.002 for x in errors),
            "abs_above_0_01": sum(x["abs"] > 0.01 for x in errors),
            "abs_above_0_05": sum(x["abs"] > 0.05 for x in errors),
            "largest_absolute_errors": sorted(errors, key=lambda x: -x["abs"])[:16]}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("uart_log", type=Path)
    args = parser.parse_args()
    captures = {"prefill32": {}, "single_token_cold": {}}
    for line in args.uart_log.read_text(errors="replace").splitlines():
        match = re.search(r"FINAL_FULL (prefill32|single_token_cold) row=(\d+)\s+(.*)", line)
        if not match:
            continue
        name, row = match[1], int(match[2])
        words = re.findall(r"\b[0-9a-fA-F]{4}\b", match[3])
        if len(words) != 576 or row in captures[name]:
            raise ValueError(f"invalid/duplicate {name} row={row}: {len(words)} values")
        captures[name][row] = [int(word, 16) for word in words]
    result = {"scope": "physical ZCU104 B0 final output, first layer without KV cache"}
    for name, rows in (("prefill32", 32), ("single_token_cold", 1)):
        if sorted(captures[name]) != list(range(rows)):
            raise ValueError(f"missing {name} rows: {sorted(captures[name])}")
        actual = [word for row in range(rows) for word in captures[name][row]]
        result[name] = analyze(actual, reference(name), rows)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
