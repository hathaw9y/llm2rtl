#!/usr/bin/env python3
"""Analyze every accepted FFN tap value from the ZCU104 UART log."""
from pathlib import Path
import argparse
import json
import math
import re
import struct

DESIGN = Path(__file__).resolve().parents[1]
REFERENCE = DESIGN / "first_layer_ffn_board_probe/ffn_vectors.h"
DOWN_REFERENCE = DESIGN / "first_layer_stage_board_probe/stage_vectors.h"
STAGES = {"post_norm": 576, "gate_projection": 1536,
          "up_projection": 1536, "silu_mul": 1536}


def bf16(word):
    return struct.unpack("<f", struct.pack("<I", word << 16))[0]


def ordered(word):
    return 0xffff - word if word & 0x8000 else word + 0x8000


def reference(case, stage):
    source = DOWN_REFERENCE if stage == "down_projection" else REFERENCE
    match = re.search(rf"static const uint16_t {case}_{stage}_full\[\d+\] = \{{(.*?)\}};",
                      source.read_text(), re.S)
    if not match:
        raise ValueError(f"missing reference {case} {stage}")
    return [int(x, 16) for x in re.findall(r"0x([0-9a-fA-F]{4})u", match[1])]


def analyze(actual, expected, columns):
    if len(actual) != len(expected):
        raise ValueError(f"length mismatch: {len(actual)} vs {len(expected)}")
    errors = []
    reference_power = 0.0
    for index, (a, e) in enumerate(zip(actual, expected)):
        av, ev = bf16(a), bf16(e)
        if not math.isfinite(av) or not math.isfinite(ev):
            raise ValueError(f"nonfinite BF16 at {index}")
        errors.append((abs(av-ev), abs(ordered(a)-ordered(e)), index, a, e))
        reference_power += ev*ev
    count = len(errors)
    squared_error = sum(x[0]*x[0] for x in errors)
    largest = sorted(errors, reverse=True)[:16]
    return {"values": count,
            "mean_abs": sum(x[0] for x in errors)/count,
            "rmse": math.sqrt(squared_error/count),
            "reference_rms": math.sqrt(reference_power/count),
            "normalized_rmse": math.sqrt(squared_error/reference_power),
            "max_abs": max(x[0] for x in errors),
            "max_ulp": max(x[1] for x in errors),
            "legacy_failures": sum(x[1] > 16 and x[0] > 0.002 for x in errors),
            "abs_above_0_01": sum(x[0] > 0.01 for x in errors),
            "largest_absolute_errors": [
                {"row": index//columns, "col": index%columns,
                 "actual_hex": f"{a:04X}", "expected_hex": f"{e:04X}",
                 "actual": bf16(a), "expected": bf16(e),
                 "abs": absolute, "ulp": ulp}
                for absolute, ulp, index, a, e in largest]}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("uart_log", type=Path)
    parser.add_argument("--input-conditioned", action="store_true",
                        help="also replay HF FFN using the captured board B5 input")
    args = parser.parse_args()
    captures = {}
    residual_captures = {}
    down_captures = {}
    pattern = re.compile(r"FFN_FULL (prefill32|single_token_cold) "
                         r"(post_norm|gate_projection|up_projection|silu_mul) "
                         r"row=(\d+) offset=(\d+)\s+(.*)")
    for line in args.uart_log.read_text(errors="replace").splitlines():
        residual_match = re.search(r"STAGE_FULL (prefill32|single_token_cold) "
                                   r"attention_residual row=(\d+)\s+(.*)", line)
        if residual_match:
            case, row = residual_match[1], int(residual_match[2])
            words = re.findall(r"\b[0-9a-fA-F]{4}\b", residual_match[3])
            if len(words) != 576 or row in residual_captures.setdefault(case, {}):
                raise ValueError(f"invalid/duplicate B5 {case} row={row}")
            residual_captures[case][row] = [int(word, 16) for word in words]
        down_match = re.search(r"STAGE_FULL (prefill32|single_token_cold) "
                               r"down_projection row=(\d+)\s+(.*)", line)
        if down_match:
            case, row = down_match[1], int(down_match[2])
            words = re.findall(r"\b[0-9a-fA-F]{4}\b", down_match[3])
            if len(words) != 576 or row in down_captures.setdefault(case, {}):
                raise ValueError(f"invalid/duplicate B1 {case} row={row}")
            down_captures[case][row] = [int(word, 16) for word in words]
        match = pattern.search(line)
        if not match:
            continue
        case, stage, row, offset = match[1], match[2], int(match[3]), int(match[4])
        words = re.findall(r"\b[0-9a-fA-F]{4}\b", match[5])
        expected_chunk = min(128, STAGES[stage]-offset)
        if offset % 128 or offset >= STAGES[stage] or len(words) != expected_chunk:
            raise ValueError(f"{case} {stage} row={row} offset={offset}: "
                             f"{len(words)} of {expected_chunk} values")
        key = case, stage
        row_chunks = captures.setdefault(key, {}).setdefault(row, {})
        if offset in row_chunks:
            raise ValueError(f"duplicate {case} {stage} row={row} offset={offset}")
        row_chunks[offset] = [int(word, 16) for word in words]
    result = {"scope": "ZCU104 PL accepted FFN writes; prefill32 and cold single token; no KV cache"}
    replay_model = None
    if args.input_conditioned:
        import sys
        import torch
        from transformers import AutoModelForCausalLM
        sys.path.insert(0, str(DESIGN.parents[1] / "verification/prototypes"))
        import smollm2_135m_isa_feasibility as isa
        torch.set_num_threads(4)
        replay_model = AutoModelForCausalLM.from_pretrained(
            str(isa.CHECKPOINT), local_files_only=True, dtype=torch.bfloat16,
            attn_implementation="eager").eval()
    for case, rows in (("prefill32", 32), ("single_token_cold", 1)):
        result[case] = {}
        replay = {}
        if replay_model is not None:
            if sorted(residual_captures.get(case, {})) != list(range(rows)):
                raise ValueError(f"missing board B5 rows for {case}")
            bits = [word for row in range(rows) for word in residual_captures[case][row]]
            import torch
            board_b5 = torch.tensor(bits, dtype=torch.uint16).view(torch.bfloat16).reshape(1, rows, 576)
            layer = replay_model.model.layers[0]
            with torch.inference_mode():
                post = layer.post_attention_layernorm(board_b5)
                gate = layer.mlp.gate_proj(post)
                up = layer.mlp.up_proj(post)
                silu = layer.mlp.act_fn(gate) * up
            for stage, value in (("post_norm", post), ("gate_projection", gate),
                                 ("up_projection", up), ("silu_mul", silu)):
                replay[stage] = value.contiguous().view(torch.uint16).reshape(-1).tolist()
        for stage, columns in STAGES.items():
            observed = captures.get((case, stage), {})
            if sorted(observed) != list(range(rows)):
                raise ValueError(f"missing {case} {stage} rows: {sorted(observed)}")
            expected_offsets = list(range(0, columns, 128))
            for row in range(rows):
                if sorted(observed[row]) != expected_offsets:
                    raise ValueError(f"missing {case} {stage} row={row} offsets")
            actual = [word for row in range(rows) for offset in expected_offsets
                      for word in observed[row][offset]]
            result[case][stage] = analyze(actual, reference(case, stage), columns)
            if replay:
                result[case][stage]["against_board_b5"] = analyze(actual, replay[stage], columns)
        if down_captures.get(case):
            if sorted(down_captures[case]) != list(range(rows)):
                raise ValueError(f"missing board B1 rows for {case}")
            actual = [word for row in range(rows) for word in down_captures[case][row]]
            result[case]["down_projection"] = analyze(actual, reference(case, "down_projection"), 576)
            if replay_model is not None:
                import torch
                replay_silu = torch.tensor(replay["silu_mul"], dtype=torch.uint16).view(torch.bfloat16).reshape(1, rows, 1536)
                board_silu_bits = [word for row in range(rows) for offset in range(0, 1536, 128)
                                   for word in captures[case, "silu_mul"][row][offset]]
                board_silu = torch.tensor(board_silu_bits, dtype=torch.uint16).view(torch.bfloat16).reshape(1, rows, 1536)
                with torch.inference_mode():
                    expected_down_from_b5 = replay_model.model.layers[0].mlp.down_proj(replay_silu)
                    expected_down = replay_model.model.layers[0].mlp.down_proj(board_silu)
                replay_down_bits = expected_down_from_b5.contiguous().view(torch.uint16).reshape(-1).tolist()
                result[case]["down_projection"]["against_board_b5"] = analyze(actual, replay_down_bits, 576)
                expected_bits = expected_down.contiguous().view(torch.uint16).reshape(-1).tolist()
                result[case]["down_projection"]["against_board_silu"] = analyze(actual, expected_bits, 576)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
