#!/usr/bin/env python3
"""Layer-0 prefill32 followed by decode1 with DDR-resident K/V."""
from __future__ import annotations
from pathlib import Path
import re
import sys
DESIGN = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(DESIGN.parents[1] / 'verification/prototypes'))
import smollm2_135m_isa_feasibility as isa

PREFILL_TOKENS = [(i * 17 + 11) % 49152 for i in range(32)]
DECODE_TOKENS = [555]

def make_program(tokens: list[int], start: int) -> isa.Program:
    rows = len(tokens)
    assert (rows, start) in ((32, 0), (1, 32))
    p = isa.Program()
    for row, token in enumerate(tokens):
        p.emit('DMA_LOAD', 0, ('embedding', token), row, rows)
    p.emit('DMA_LOAD', 7, ('rope', start, rows))
    p.emit('DMA_LOAD', 3, ('weight', 0, 'input_layernorm', 0))
    p.emit('RMSNORM', 0, 3, 2, rows)
    isa.gemm_tiles(p, 0, 'q_proj', 2, 4, 576, rows)
    isa.gemm_tiles(p, 0, 'k_proj', 2, 5, 192, rows)
    isa.gemm_tiles(p, 0, 'v_proj', 2, 6, 192, rows)
    p.emit('ROPE', 4, 7, rows)
    p.emit('ROPE', 5, 7, rows)
    p.emit('DMA_STORE', 5, ('kv', 0, 'key', start), rows)
    p.emit('DMA_STORE', 6, ('kv', 0, 'value', start), rows)
    p.emit('FENCE')
    p.emit('DMA_LOAD', 8, ('kv', 0, 'key', start + rows))
    p.emit('DMA_LOAD', 9, ('kv', 0, 'value', start + rows))
    p.emit('ATTN_SCORE', 4, 8, 10, start, rows, start + rows)
    p.emit('SOFTMAX', 10, start, rows, start + rows)
    p.emit('ATTN_VALUE', 10, 9, 11, start, rows, start + rows)
    isa.gemm_tiles(p, 0, 'o_proj', 11, 1, 576, rows)
    p.emit('ADD', 0, 1, 5, rows)
    p.emit('DMA_LOAD', 3, ('weight', 0, 'post_attention_layernorm', 0))
    p.emit('RMSNORM', 5, 3, 2, rows)
    isa.gemm_tiles(p, 0, 'gate_proj', 2, 8, 1536, rows)
    isa.gemm_tiles(p, 0, 'up_proj', 2, 9, 1536, rows)
    p.emit('SILU_MUL', 8, 9, 10, rows)
    isa.gemm_tiles(p, 0, 'down_proj', 10, 1, 576, rows)
    p.emit('ADD', 5, 1, 0, rows)
    operations = p.current
    p.current = []
    p.chunks = [operations[i:i+15] + [isa.Cmd('END')]
                for i in range(0, len(operations), 15)]
    assert all(len(c) <= 16 for c in p.chunks)
    return p

def check_dispatcher_roles(program: isa.Program) -> None:
    text = (DESIGN / 'rtl/isa_command_dispatcher.sv').read_text()
    section = text.split('function automatic logic bank_allowed',1)[1].split('endfunction',1)[0]
    permissions = {int(role): {int(x) for x in re.findall(r'bank == (\d+)',expr)}
                   for role,expr in re.findall(r'^\s*(\d+): bank_allowed = (.*?);',section,re.M|re.S)}
    roles = {'DMA_LOAD':(1,), 'DMA_STORE':(2,), 'GEMM':(3,4,5),
             'RMSNORM':(6,7,8), 'ROPE':(9,10), 'ATTN_SCORE':(11,12,13),
             'SOFTMAX':(14,), 'ATTN_VALUE':(15,16,17),
             'ADD':(18,19,20), 'SILU_MUL':(18,19,20),
             'FENCE':(), 'END':()}
    for chunk in program.chunks:
        for cmd in chunk:
            for pos,role in enumerate(roles[cmd.op]):
                assert cmd.args[pos] in permissions[role], (cmd,role)
