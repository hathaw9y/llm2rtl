#!/usr/bin/env python3
"""Build and test the layer-0 ISA sequence without DDR KV cache traffic."""
from __future__ import annotations

from collections import Counter
from pathlib import Path
import hashlib
import json
import re
import sys

import torch
from transformers import AutoModelForCausalLM

DESIGN = Path(__file__).resolve().parents[1]
ROOT = DESIGN.parents[1]
sys.path.insert(0, str(ROOT / "verification/prototypes"))
import smollm2_135m_isa_feasibility as isa  # noqa: E402

REVISION = "93efa2f097d58c2a74874c7e644dbc9b0cee75a2"
OUTPUT = DESIGN / "golden/first_layer_no_kv_isa_candidate"


def make_program(tokens: list[int]) -> isa.Program:
    rows = len(tokens)
    assert rows in (1, 32)
    p = isa.Program()
    for row, token in enumerate(tokens):
        p.emit("DMA_LOAD", 0, ("embedding", token), row, rows)
    p.emit("DMA_LOAD", 7, ("rope", 0, rows))
    p.emit("DMA_LOAD", 3, ("weight", 0, "input_layernorm", 0))
    p.emit("RMSNORM", 0, 3, 2, rows)
    isa.gemm_tiles(p, 0, "q_proj", 2, 4, 576, rows)
    isa.gemm_tiles(p, 0, "k_proj", 2, 8, 192, rows)
    isa.gemm_tiles(p, 0, "v_proj", 2, 9, 192, rows)
    p.emit("ROPE", 4, 7, rows)
    p.emit("ROPE", 8, 7, rows)
    p.emit("ATTN_SCORE", 4, 8, 10, 0, rows, rows)
    p.emit("SOFTMAX", 10, 0, rows, rows)
    p.emit("ATTN_VALUE", 10, 9, 11, 0, rows, rows)
    isa.gemm_tiles(p, 0, "o_proj", 11, 1, 576, rows)
    p.emit("ADD", 0, 1, 5, rows)
    p.emit("DMA_LOAD", 3, ("weight", 0, "post_attention_layernorm", 0))
    p.emit("RMSNORM", 5, 3, 2, rows)
    isa.gemm_tiles(p, 0, "gate_proj", 2, 8, 1536, rows)
    isa.gemm_tiles(p, 0, "up_proj", 2, 9, 1536, rows)
    p.emit("SILU_MUL", 8, 9, 10, rows)
    isa.gemm_tiles(p, 0, "down_proj", 10, 1, 576, rows)
    p.emit("ADD", 5, 1, 0, rows)
    p.end()
    # The current GPIO board shell exposes only 16 command BRAM records.
    # END/DONE drains a chunk while the bank contents remain resident.
    operations = [cmd for chunk in p.chunks for cmd in chunk if cmd.op != "END"]
    p.chunks = [operations[i:i + 15] + [isa.Cmd("END")]
                for i in range(0, len(operations), 15)]
    assert all(len(chunk) <= 16 for chunk in p.chunks)
    return p


class LayerMachine(isa.Machine):
    def check_oracle(self, cmd: isa.Cmd):
        super().check_oracle(cmd)
        if cmd.op == "ROPE" and cmd.args[0] == 8 and self.oracle:
            actual = self.get(8).reshape(-1, 3, 64).transpose(0, 1)
            expected = self.oracle["cache"].layers[0].keys[0]
            assert torch.equal(actual, expected), isa.compare("ROPE_key_B8", actual, expected)
            self.oracle_checks["ROPE_key_B8"] += 1


def rtl_blockers(program: isa.Program) -> list[dict]:
    dispatcher = (DESIGN / "rtl/isa_command_dispatcher.sv").read_text()
    router = (DESIGN / "rtl/smollm2_bank_port_router_wide.sv").read_text()
    rope = (DESIGN / "rtl/smollm2_rope_executor.sv").read_text()
    probe = (DESIGN / "rtl/smollm2_dma_gemm_board_probe.sv").read_text()

    def bank_permissions(source: str) -> dict[int, set[int]]:
        section = source.split("function automatic logic bank_allowed", 1)[1]
        section = section.split("endfunction", 1)[0]
        return {int(role): {int(bank) for bank in re.findall(r"bank == (\d+)", expr)}
                for role, expr in re.findall(r"^\s*(\d+): bank_allowed = (.*?);",
                                             section, re.M | re.S)}

    permitted = bank_permissions(dispatcher)
    assert permitted == bank_permissions(router), "dispatcher/router bank roles differ"
    assert permitted[9] == {4, 5, 8}
    assert "cmd_bank[0] != 4'd8" in rope
    assert "FULL_LAYER_PROBE && add_write_bank == 4'd0" in probe
    role_by_op = {
        "DMA_LOAD": (1,), "RMSNORM": (6, 7, 8),
        "GEMM": (3, 4, 5), "ROPE": (9, 10),
        "ATTN_SCORE": (11, 12, 13), "SOFTMAX": (14,),
        "ATTN_VALUE": (15, 16, 17), "ADD": (18, 19, 20),
        "SILU_MUL": (18, 19, 20), "END": (),
    }
    blockers = []
    for pc, cmd in enumerate(cmd for chunk in program.chunks for cmd in chunk):
        for position, role in enumerate(role_by_op[cmd.op]):
            bank = cmd.args[position]
            if bank not in permitted[role]:
                blockers.append({"pc": pc, "record": f"{cmd.op} role{role} B{bank}",
                                 "gate": "dispatcher and bank router reject this bank role"})
    return blockers


def main() -> None:
    torch.set_num_threads(4)
    model = AutoModelForCausalLM.from_pretrained(
        str(isa.CHECKPOINT), local_files_only=True, dtype=torch.bfloat16,
        attn_implementation="eager").eval()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    cases = {}
    for name, tokens in (
        ("prefill32", [(i * 17 + 11) % 49152 for i in range(32)]),
        ("single_token_cold", [11]),
    ):
        ddr = isa.DDR(model, tokens)
        program = make_program(tokens)
        commands = [cmd for chunk in program.chunks for cmd in chunk]
        records = [isa.wire_record(cmd, ddr) for cmd in commands]
        assert all(isa.wire_decode(record, ddr) == cmd
                   for record, cmd in zip(records, commands))
        assert not any(cmd.op in ("DMA_STORE", "FENCE") for cmd in commands)
        captured = {}
        hooks = isa.install_reference_hooks(model, captured)
        with torch.inference_mode():
            reference = model(torch.tensor([tokens]), use_cache=True,
                              logits_to_keep=1)
            machine = LayerMachine(ddr)
            machine.oracle = {"captured": captured, "cache": reference.past_key_values,
                              "start": 0, "m": len(tokens)}
            machine.run(program)
        for hook in hooks:
            hook.remove()
        actual = machine.get(0)
        expected = captured[0, "layer_output"][0]
        result = isa.compare(name, actual, expected)
        assert result["exact"], result
        blockers = rtl_blockers(program)
        assert not blockers, blockers
        (OUTPUT / f"{name}_commands.hex").write_text(
            "".join(f"{record:032x}\n" for record in records))
        (OUTPUT / f"{name}_commands.json").write_text(json.dumps([
            {"stream_index": pc, "record_hex": f"{record:032x}",
             "opcode": cmd.op, "operands": cmd.args}
            for pc, (record, cmd) in enumerate(zip(records, commands))
        ], indent=2) + "\n")
        cases[name] = {
            "tokens": tokens, "rows": len(tokens), "commands": len(records),
            "chunks": len(program.chunks),
            "chunk_record_counts": [len(chunk) for chunk in program.chunks],
            "command_bytes": len(records) * 16, "opcode_counts": dict(Counter(
                cmd.op for cmd in commands)),
            "end_to_end_layer_output": result,
            "oracle_checks": dict(machine.oracle_checks),
            "current_rtl_blockers": blockers,
            "records_sha256": hashlib.sha256((OUTPUT / f"{name}_commands.hex").read_bytes()).hexdigest(),
        }
    summary = {
        "checkpoint_revision": REVISION,
        "status": "candidate_functional_pass_rtl_enabled_board_pending",
        "scope": "layer 0 from embedding to post-FFN residual; positions start at zero; no KV cache store/load or reuse",
        "host_role": "tokens, dimensions, static DDR addresses and ISA scheduling only; tensor operations in interpreter/PL model",
        "rtl_change": "ROPE B8 enabled in dispatcher, router, executor and board probe; final ADD B0 exposed for board comparison",
        "bank_capacity_check": "every interpreter bank write is checked against the existing 13-bank capacity table",
        "cases": cases,
    }
    (OUTPUT / "result.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({name: {"commands": c["commands"],
                             "exact": c["end_to_end_layer_output"]["exact"],
                             "blockers": c["current_rtl_blockers"]}
                      for name, c in cases.items()}, indent=2))


if __name__ == "__main__":
    main()
