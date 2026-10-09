#!/usr/bin/env python3
"""Analyze UART FINAL_VALUES from the unchanged first-layer ZCU104 BIT."""
from pathlib import Path
import argparse
import json
import math
import re
import struct

DESIGN = Path(__file__).resolve().parents[1]
REFERENCE = DESIGN / "first_layer_no_kv_board_probe/quality_reference.json"


def as_float(bits: int) -> float:
    return struct.unpack("<f", struct.pack("<I", bits << 16))[0]


def ordered(bits: int) -> int:
    return 0xffff - bits if bits & 0x8000 else bits + 0x8000


def analyze(actual: list[list[int]], expected: list[list[int]]) -> dict:
    assert len(actual) == len(expected)
    rows = len(actual)
    errors = []
    for row in range(rows):
        assert len(actual[row]) == len(expected[row]) == 16
        for col, (a, e) in enumerate(zip(actual[row], expected[row])):
            av, ev = as_float(a), as_float(e)
            errors.append({"row": row, "col": col, "actual_hex": f"{a:04x}",
                           "expected_hex": f"{e:04x}", "actual": av,
                           "expected": ev, "abs": abs(av - ev),
                           "ulp": abs(ordered(a) - ordered(e))})
    mse = sum(x["abs"] ** 2 for x in errors) / len(errors)
    ref_mse = sum(x["expected"] ** 2 for x in errors) / len(errors)
    return {"values": len(errors), "mean_abs": sum(x["abs"] for x in errors) / len(errors),
            "rmse": math.sqrt(mse), "reference_rms": math.sqrt(ref_mse),
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
    text = args.uart_log.read_text(errors="replace")
    lines = []
    for row, values in re.findall(r"FINAL_VALUES row=(\d+)\s+((?:[0-9a-fA-F]{4}\s+){15}[0-9a-fA-F]{4})", text):
        lines.append((int(row), [int(word, 16) for word in values.split()]))
    if len(lines) != 33:
        raise ValueError(f"expected 32 prefill rows and one cold row; got {len(lines)} FINAL_VALUES lines")
    if [row for row, _ in lines] != list(range(32)) + [0]:
        raise ValueError("FINAL_VALUES row order does not match prefill32 then cold single token")
    reference = json.loads(REFERENCE.read_text())
    result = {
        "scope": "first 16 of 576 BF16 output values per row on the physical board",
        "prefill32": analyze([v for _, v in lines[:32]],
                             [[int(x, 16) for x in row] for row in reference["prefill32"]]),
        "single_token_cold": analyze([lines[-1][1]],
                                      [[int(x, 16) for x in reference["single_token_cold"][0]]]),
    }
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
