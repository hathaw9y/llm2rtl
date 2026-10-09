#!/usr/bin/env python3
"""Evaluate the fixed prefill32/decode1 performance probe on ZCU104.

The operation count is nominal dense GEMM + attention arithmetic. One MAC is
two operations. It excludes RMSNorm, RoPE, softmax, ADD, SiLU and DMA activity.
Attention counts the full query-by-KV rectangle, including masked positions;
it excludes implementation padding. This is a workload convention, not a PE
utilization measurement.

Input is the raw UART text from the PERF_ONLY SD-backed board app. Its
PERF_BLOCK time includes ISA issue, DMA, PL execution and completion polling,
but excludes SD loading, UART diagnostics and golden comparisons. Supply the
average power measured over each timed block for a measured TOPS/W result.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys

LAYERS = 30
HIDDEN = 576
KV_WIDTH = 192
FFN = 1536
QUERY_HEADS = 9
HEAD_DIM = 64
VOCAB = 49152

PERF_BLOCK = re.compile(rb"\bPERF_BLOCK\s+(prefill32|decode1)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\b")
PERF_BEGIN = re.compile(rb"\bPERF_BEGIN\s+(prefill32|decode1)\s+(\d+)\s+(\d+)\b")


def blocks_from_log(data: bytes) -> list[dict]:
    matches = list(PERF_BLOCK.finditer(data))
    beginnings = list(PERF_BEGIN.finditer(data))
    if len(matches) != 2:
        raise ValueError(f"expected exactly two PERF_BLOCK records, found {len(matches)}; "
                         "use the PERF_ONLY ELF, not the earlier numeric probe")
    if len(beginnings) != 2:
        raise ValueError(f"expected exactly two PERF_BEGIN records, found {len(beginnings)}")
    blocks = []
    for beginning, match in zip(beginnings, matches):
        if beginning.start() >= match.start() or beginning.groups() != match.groups()[:3]:
            raise ValueError("PERF_BEGIN and PERF_BLOCK order or workload differs")
        name = match.group(1).decode("ascii")
        start, end, chunks, us = map(int, match.groups()[1:])
        blocks.append(dict(name=name, start=start, end=end,
                           chunks=chunks, time_us=us))
    if not re.search(rb"\bBOARD FIXED PERFORMANCE ISA EXECUTION COMPLETE\b", data):
        raise ValueError("missing successful board completion marker")
    return blocks


def nominal_ops(rows: int, kv_len: int, logits: bool) -> int:
    # Q, K, V, O, gate, up and down projections in each decoder layer.
    projection_mac_per_row = (
        2 * HIDDEN * HIDDEN + 2 * HIDDEN * KV_WIDTH +
        3 * HIDDEN * FFN
    )
    projection_macs = LAYERS * rows * projection_mac_per_row
    # ATTN_SCORE Q*K^T and ATTN_VALUE P*V, all Q heads and KV positions.
    attention_macs = LAYERS * 2 * QUERY_HEADS * HEAD_DIM * rows * kv_len
    lm_head_macs = HIDDEN * VOCAB if logits else 0
    return 2 * (projection_macs + attention_macs + lm_head_macs)


def summarize(blocks: list[dict], power_w: float | None) -> dict:
    seconds = sum(block["time_us"] for block in blocks) / 1_000_000
    tokens = sum(block["rows"] for block in blocks)
    ops = sum(block["nominal_ops"] for block in blocks)
    result = {
        "blocks": len(blocks), "tokens_processed": tokens,
        "board_compute_seconds": seconds, "nominal_ops": ops,
        "tokens_per_second": tokens / seconds,
        "nominal_gops_per_second": ops / seconds / 1e9,
    }
    if power_w is not None:
        result["average_power_w"] = power_w
        result["joules"] = seconds * power_w
        result["tokens_per_joule"] = tokens / (seconds * power_w)
        result["joules_per_token"] = seconds * power_w / tokens
        result["nominal_tops_per_watt"] = ops / seconds / power_w / 1e12
    return result


def evaluate(data: bytes, prefill_power_w: float | None,
             decode_power_w: float | None, power_source: str | None,
             power_scope: str | None) -> dict:
    if (prefill_power_w is None) != (decode_power_w is None):
        raise ValueError("supply both --prefill-power-w and --decode-power-w")
    if prefill_power_w is not None:
        if not all(0 < value < float("inf") for value in (prefill_power_w, decode_power_w)):
            raise ValueError("both power readings must be finite and positive")
    if (prefill_power_w is None) != (power_source is None) or (prefill_power_w is None) != (power_scope is None):
        raise ValueError("power readings, --power-source and --power-scope must be supplied together")

    blocks = blocks_from_log(data)
    for block, expected in zip(blocks, (("prefill32", 0, 32), ("decode1", 32, 33))):
        if (block["name"], block["start"], block["end"]) != expected or block["time_us"] <= 0:
            raise ValueError(f"unexpected fixed-workload block: {block}")
        block.update(rows=block["end"] - block["start"],
                     kv_len=block["end"], logits=True,
                     nominal_ops=nominal_ops(block["end"] - block["start"],
                                             block["end"], True))
    prefill, decode = [blocks[0]], [blocks[1]]
    total_seconds = sum(block["time_us"] for block in blocks) / 1_000_000
    total_power_w = None
    if prefill_power_w is not None:
        total_power_w = (blocks[0]["time_us"] * prefill_power_w +
                         blocks[1]["time_us"] * decode_power_w) / (total_seconds * 1_000_000)

    report = {
        "metric_definition": "nominal dense BF16 GEMM+attention; 1 MAC = 2 operations",
        "model": "HuggingFaceTB/SmolLM2-135M",
        "checkpoint": "93efa2f097d58c2a74874c7e644dbc9b0cee75a2",
        "log_source": "fixed_perf_uart",
        "timing_scope": "A53 PERF_BLOCK; ISA issue, DMA, PL execution and polling; excludes SD, UART diagnostics and golden comparisons",
        "power_source": power_source,
        "power_scope": power_scope,
        "status": "measured_timing_and_power" if power_source == "measured" else
                  "timing_with_estimated_power" if power_source else "power_missing",
        "prefill": summarize(prefill, prefill_power_w),
        "decode": summarize(decode, decode_power_w),
        "all_blocks": summarize(blocks, total_power_w),
        "blocks": blocks,
    }
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", required=True, type=Path,
                        help="UART text from fixed PERF_ONLY prefill32/decode1 ELF")
    parser.add_argument("--prefill-power-w", type=float,
                        help="Measured mean W during the prefill PERF_BLOCK")
    parser.add_argument("--decode-power-w", type=float,
                        help="Measured mean W during the decode PERF_BLOCK")
    parser.add_argument("--power-source", choices=("measured", "vivado_estimate"),
                        help="Power evidence; required with --power-w")
    parser.add_argument("--power-scope", choices=("board_input", "soc_rails", "on_chip_estimate"),
                        help="Which rails or system the W value covers")
    parser.add_argument("--json-out", type=Path,
                        help="Save complete machine-readable result")
    args = parser.parse_args()
    try:
        report = evaluate(args.log.read_bytes(), args.prefill_power_w,
                          args.decode_power_w, args.power_source, args.power_scope)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    for phase in ("prefill", "decode", "all_blocks"):
        item = report[phase]
        if item is None:
            continue
        print(f"{phase}: {item['tokens_processed']} tokens, "
              f"{item['board_compute_seconds']:.6f} s, "
              f"{item['tokens_per_second']:.4f} tokens/s, "
              f"{item['nominal_gops_per_second']:.4f} nominal GOPS")
        if args.prefill_power_w is not None:
            print(f"  {item['nominal_tops_per_watt']:.6f} nominal TOPS/W, "
                  f"{item['tokens_per_joule']:.6f} tokens/J, "
                  f"{item['joules_per_token']:.6f} J/token "
                  f"[{args.power_source}, {args.power_scope}]")
    if args.prefill_power_w is None:
        print("TOPS/W and tokens/J unavailable: supply measured average power")
    elif args.power_source != "measured":
        print("Power is estimated; these are estimated, not measured efficiency results")
    if args.json_out:
        args.json_out.write_text(json.dumps(report, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
