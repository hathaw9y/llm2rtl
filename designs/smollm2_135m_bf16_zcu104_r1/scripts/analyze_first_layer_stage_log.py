#!/usr/bin/env python3
"""Compare complete B5/B1 diagnostic tap values with frozen HF BF16 vectors."""
from pathlib import Path
import argparse
import json
import re
import struct

from analyze_first_layer_full_output_log import analyze, bf16, reference as final_reference

DESIGN = Path(__file__).resolve().parents[1]
REFERENCE = DESIGN / "first_layer_stage_board_probe/stage_vectors.h"


def reference(name: str) -> list[int]:
    source = REFERENCE.read_text()
    match = re.search(rf"static const uint16_t {name}\[\d+\] = \{{(.*?)\}};",
                      source, re.S)
    if not match:
        raise ValueError(f"reference {name} missing")
    return [int(word, 16) for word in re.findall(r"0x([0-9a-fA-F]{4})u", match[1])]


def bf16_rne(value: float) -> int:
    bits = struct.unpack("<I", struct.pack("<f", value))[0]
    return ((bits + 0x7fff + ((bits >> 16) & 1)) >> 16) & 0xffff


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("uart_log", type=Path)
    args = parser.parse_args()
    captures = {}
    final_captures = {}
    for line in args.uart_log.read_text(errors="replace").splitlines():
        final_match = re.search(r"FINAL_FULL (prefill32|single_token_cold) row=(\d+)\s+(.*)", line)
        if final_match:
            case, row = final_match[1], int(final_match[2])
            words = re.findall(r"\b[0-9a-fA-F]{4}\b", final_match[3])
            if len(words) != 576 or row in final_captures.setdefault(case, {}):
                raise ValueError(f"invalid/duplicate final {case} row={row}: {len(words)} values")
            final_captures[case][row] = [int(word, 16) for word in words]
        match = re.search(r"STAGE_FULL (prefill32|single_token_cold) "
                          r"(attention_residual|down_projection) row=(\d+)\s+(.*)", line)
        if not match:
            continue
        case, stage, row = match[1], match[2], int(match[3])
        words = re.findall(r"\b[0-9a-fA-F]{4}\b", match[4])
        if len(words) != 576 or row in captures.setdefault((case, stage), {}):
            raise ValueError(f"invalid/duplicate {case} {stage} row={row}: {len(words)} values")
        captures[case, stage][row] = [int(word, 16) for word in words]
    result = {"scope": "ZCU104 first-layer no-KV accepted B5 ADD and B1 GEMM writes"}
    for case, rows in (("prefill32", 32), ("single_token_cold", 1)):
        result[case] = {}
        for stage in ("attention_residual", "down_projection"):
            observed = captures.get((case, stage), {})
            if sorted(observed) != list(range(rows)):
                raise ValueError(f"missing {case} {stage} rows: {sorted(observed)}")
            actual = [word for row in range(rows) for word in observed[row]]
            result[case][stage] = analyze(actual, reference(f"{case}_{stage}_full"), rows)
        final_rows = final_captures.get(case, {})
        if sorted(final_rows) != list(range(rows)):
            raise ValueError(f"missing final {case} rows: {sorted(final_rows)}")
        final = [word for row in range(rows) for word in final_rows[row]]
        residual = [word for row in range(rows) for word in captures[case, "attention_residual"][row]]
        down = [word for row in range(rows) for word in captures[case, "down_projection"][row]]
        recomputed = [bf16_rne(bf16(left) + bf16(right))
                      for left, right in zip(residual, down)]
        result[case]["final_add_identity"] = {
            "values": rows * 576,
            "exact_matches": sum(a == b for a, b in zip(final, recomputed)),
            "mismatches": sum(a != b for a, b in zip(final, recomputed)),
        }
        result[case]["final_output"] = analyze(final, final_reference(case), rows)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
