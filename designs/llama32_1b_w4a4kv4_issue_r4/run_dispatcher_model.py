#!/usr/bin/env python3
"""Event reference for in-order issue with bank-acquire/completion-release."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


BASE = Path(__file__).resolve().parent


def command_banks(command):
    opcode = command["opcode"]
    if opcode == "DMA_LOAD":
        return set(), {command["bank"]}
    if opcode == "DMA_STORE":
        return {command["bank"]}, set()
    if opcode == "GEMM":
        return {command["src1"], command["src2"], command["dst"]}, {command["dst"]}
    return set(), set()


def run_case(case):
    pc = 0
    busy = set()
    issue_order = []
    max_outstanding = 0
    outstanding = 0
    terminal = None
    end_seen = False
    stopped = False
    stalled_pcs = []

    for event in case["events"]:
        kind, _, value = event.partition(":")
        bank = int(value) if value else None
        if kind == "issue":
            assert not stopped and pc == bank
            command = case["commands"][pc]
            reads, writes = command_banks(command)
            owned = reads | writes
            assert all(item not in busy for item in owned)
            busy |= owned
            issue_order.append(pc)
            outstanding += 1
            pc += 1
        elif kind == "stall":
            assert pc == bank
            command = case["commands"][pc]
            reads, writes = command_banks(command)
            assert any(item in busy for item in reads | writes)
            stalled_pcs.append(pc)
        elif kind == "see_end":
            assert pc == bank and case["commands"][pc]["opcode"] == "END"
            end_seen = True
            stopped = True
        elif kind == "complete_load":
            assert bank in busy
            busy.remove(bank)
            outstanding -= 1
        elif kind == "complete_store":
            assert bank in busy
            busy.remove(bank)
            outstanding -= 1
        elif kind == "complete_gemm":
            command = next(cmd for cmd in case["commands"]
                           if cmd["opcode"] == "GEMM" and cmd["dst"] == bank)
            busy -= {command["src1"], command["src2"], command["dst"]}
            outstanding -= 1
        elif kind == "error_load":
            assert bank in busy
            busy.remove(bank)
            outstanding -= 1
            stopped = True
            terminal = "error"
        else:
            raise AssertionError(f"unknown event {event}")
        max_outstanding = max(max_outstanding, outstanding)

    if terminal is None and end_seen and not busy:
        terminal = "done"
    return {
        "pc": pc,
        "issue_order": issue_order,
        "max_outstanding": max_outstanding,
        "stalled_pcs": stalled_pcs,
        "terminal": terminal,
    }


def main():
    path = BASE / "vectors" / "dispatcher_cases.json"
    document = json.loads(path.read_text())
    results = []
    for case in document["cases"]:
        actual = run_case(case)
        assert actual["issue_order"] == case["expected_issue_order"], case["case_id"]
        if "expected_max_outstanding" in case:
            assert actual["max_outstanding"] == case["expected_max_outstanding"], case["case_id"]
        if "expected_stalled_pc" in case:
            assert case["expected_stalled_pc"] in actual["stalled_pcs"], case["case_id"]
        if "expected_not_issued_pc" in case:
            assert case["expected_not_issued_pc"] not in actual["issue_order"], case["case_id"]
        assert actual["terminal"] == case["expected_terminal"], case["case_id"]
        results.append({"case_id": case["case_id"], **actual})
    print(json.dumps({
        "status": "passed",
        "case_count": len(results),
        "vector_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "results": results,
        "limitations": "Unified exclusive acquire/release control model only; no bank data or tensor arithmetic."
    }, indent=2))


if __name__ == "__main__":
    main()
