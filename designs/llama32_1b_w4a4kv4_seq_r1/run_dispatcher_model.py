#!/usr/bin/env python3
"""Reference model for the strict single-PC, one-outstanding dispatcher."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


BASE = Path(__file__).resolve().parent


def run_case(case):
    banks = list(case["initial_banks"])
    pc = 0
    issued_tags = []
    terminal = "done"
    while pc < len(case["commands"]):
        command = case["commands"][pc]
        opcode = command["opcode"]
        if opcode == "DMA_LOAD":
            ready = banks[command["dst"]] == "free"
        elif opcode == "DMA_STORE":
            ready = banks[command["src0"]] == "ready"
        elif opcode == "GEMM":
            ready = (banks[command["src0"]] == "ready"
                     and banks[command["src1"]] == "ready"
                     and banks[command["dst"]] == "free")
        else:
            ready = False
        if not ready:
            terminal = "stalled"
            break

        issued_tags.append(command["tag"])
        if opcode == "DMA_LOAD":
            banks[command["dst"]] = "filling"
        elif opcode == "DMA_STORE":
            banks[command["src0"]] = "draining"
        else:
            banks[command["dst"]] = "compute_active"

        if not command["success"]:
            if opcode in ("DMA_LOAD", "GEMM"):
                banks[command["dst"]] = "fault"
            elif opcode == "DMA_STORE":
                banks[command["src0"]] = "ready"
            terminal = "error"
            break

        if opcode == "DMA_LOAD":
            banks[command["dst"]] = "ready"
        elif opcode == "DMA_STORE":
            banks[command["src0"]] = "free" if command.get("release_src") else "ready"
        else:
            banks[command["dst"]] = "ready"
        pc += 1

    return {"pc": pc, "banks": banks, "issued_tags": issued_tags, "terminal": terminal}


def main():
    vector_path = BASE / "vectors" / "dispatcher_cases.json"
    document = json.loads(vector_path.read_text())
    results = []
    for case in document["cases"]:
        actual = run_case(case)
        if "expected_final_banks" in case:
            assert actual["banks"] == case["expected_final_banks"], case["case_id"]
        if "expected_stalled_pc" in case:
            assert actual["pc"] == case["expected_stalled_pc"], case["case_id"]
        if "expected_stopped_before_tag" in case:
            assert case["expected_stopped_before_tag"] not in actual["issued_tags"], case["case_id"]
        assert actual["terminal"] == case["expected_terminal_state"], case["case_id"]
        results.append({"case_id": case["case_id"], **actual})
    report = {
        "status": "passed",
        "case_count": len(results),
        "vector_sha256": hashlib.sha256(vector_path.read_bytes()).hexdigest(),
        "results": results,
        "limitations": "Control/state reference only; no tensor arithmetic or RTL evidence."
    }
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
