#!/usr/bin/env python3
"""Check router role-bank capabilities against the actual ISA program builder."""
from __future__ import annotations

import __future__
import ast
import dataclasses
import json
from pathlib import Path
import re

DESIGN = Path(__file__).resolve().parents[1]
ROOT = DESIGN.parents[1]
BUILDER = ROOT / "verification/prototypes/smollm2_135m_isa_feasibility.py"
CONTRACT = DESIGN / "modules/smollm2_bank_port_router.json"
RTL = DESIGN / "rtl/smollm2_bank_port_router.sv"
DISPATCHER = DESIGN / "rtl/isa_command_dispatcher.sv"
DMA_BRIDGE = DESIGN / "rtl/smollm2_dma_bank_bridge.sv"
DMA_BRIDGE_CONTRACT = DESIGN / "modules/smollm2_dma_bank_bridge.json"
ROLE_BY_OPCODE = {
    "DMA_LOAD": (1,), "DMA_STORE": (2,), "GEMM": (3, 4, 5),
    "RMSNORM": (6, 7, 8), "ROPE": (9, 10),
    "ATTN_SCORE": (11, 12, 13), "SOFTMAX": (14,),
    "ATTN_VALUE": (15, 16, 17), "ADD": (18, 19, 20),
    "SILU_MUL": (18, 19, 20),
}

tree = ast.parse(BUILDER.read_text())
nodes = [node for node in tree.body if isinstance(node, (ast.FunctionDef, ast.ClassDef))
         and node.name in {"Cmd", "Program", "gemm_tiles", "build_block"}]
scope = {"dataclass": dataclasses.dataclass, "field": dataclasses.field}
exec(compile(ast.Module(body=nodes, type_ignores=[]), str(BUILDER), "exec",
             flags=__future__.annotations.compiler_flag), scope)

actual = {role: set() for role in range(1, 21)}
for tokens, start in (([1], 0), ([1] * 32, 992)):
    program = scope["build_block"](tokens, start, True)
    for chunk in program.chunks:
        for command in chunk:
            if command.op in ROLE_BY_OPCODE:
                for role, bank in zip(ROLE_BY_OPCODE[command.op], command.args):
                    actual[role].add(bank)

contract = json.loads(CONTRACT.read_text())
declared = {int(role): set(banks) for role, banks in
            contract["control_rules"]["role_bank_pairs"].items()}
if actual != declared:
    raise SystemExit(f"contract mismatch: actual={actual}, declared={declared}")

for rtl_path in (RTL, DISPATCHER):
    rtl = rtl_path.read_text()
    body = rtl.split("function automatic logic bank_allowed", 1)[1].split("endfunction", 1)[0]
    found = {}
    for match in re.finditer(r"^\s*(\d+): bank_allowed\s*=\s*(.*?);", body, re.M | re.S):
        found[int(match.group(1))] = {int(bank) for bank in
                                      re.findall(r"bank\s*==\s*(\d+)", match.group(2))}
    if found != declared:
        raise SystemExit(f"RTL mismatch in {rtl_path}: rtl={found}, declared={declared}")

bridge_contract = json.loads(DMA_BRIDGE_CONTRACT.read_text())["interface"]
bridge_rtl = DMA_BRIDGE.read_text()
for role, signal, key in ((1, "wr_grant", "legal_load_banks"),
                          (2, "rd_grant", "legal_store_banks")):
    declared_banks = set(bridge_contract[key])
    grant_match = re.search(rf"assign\s+{signal}\[bank\]\s*=(.*?);", bridge_rtl, re.S)
    if grant_match is None:
        raise SystemExit(f"missing bridge grant {signal}")
    rtl_banks = {int(bank) for bank in re.findall(r"bank\s*==\s*(\d+)",
                                                grant_match.group(1))}
    if declared_banks != actual[role] or rtl_banks != actual[role]:
        raise SystemExit(f"DMA bridge mismatch role={role}: actual={actual[role]}, "
                         f"contract={declared_banks}, rtl={rtl_banks}")
print("PASS 20 role-bank sets match prefill/decode, contract, router, dispatcher and DMA bridge")
