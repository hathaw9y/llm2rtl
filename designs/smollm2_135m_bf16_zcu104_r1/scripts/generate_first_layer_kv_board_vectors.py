#!/usr/bin/env python3
"""Freeze real checkpoint inputs, K/V and layer output for prefill32 -> decode1."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import sys
import torch
from transformers import AutoModelForCausalLM
D = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(D / 'scripts'))
from check_first_layer_kv_isa_candidate import make_program, check_dispatcher_roles, PREFILL_TOKENS, DECODE_TOKENS
sys.path.insert(0, str(D.parents[1] / 'verification/prototypes'))
import smollm2_135m_isa_feasibility as isa
OUT = D / 'first_layer_kv_board_probe'
OUT.mkdir(exist_ok=True)

def packed_words(value):
    bits = value.contiguous().view(torch.uint16).reshape(-1).tolist()
    assert len(bits)%8 == 0
    return [sum(int(bits[i+j]) << (16*j) for j in range(8)) for i in range(0,len(bits),8)]

def c_words(name, words):
    return ('static const uint32_t '+name+f'[{len(words)}][4] __attribute__((aligned(64))) = {{\n'+
            '\n'.join('  {'+','.join(f'0x{(w>>(32*j))&0xffffffff:08x}u' for j in range(4))+'},' for w in words)+'\n};')

def c_bf16(name, tensor):
    bits = tensor.contiguous().view(torch.uint16).reshape(-1).tolist()
    return f'static const uint16_t {name}[{len(bits)}] = {{\n'+','.join(f'0x{int(x):04x}u' for x in bits)+'\n};'

torch.set_num_threads(4)
model=AutoModelForCausalLM.from_pretrained(str(isa.CHECKPOINT),local_files_only=True,dtype=torch.bfloat16,attn_implementation='eager').eval()
ddr=isa.DDR(model,PREFILL_TOKENS)
# Reuse the frozen first-layer weight array and its exact tile order.
from check_first_layer_no_kv_isa_candidate import make_program as old_program
weight_keys=[]
for chunk in old_program(PREFILL_TOKENS).chunks:
    for cmd in chunk:
        if cmd.op=='DMA_LOAD' and cmd.args[1][0]=='weight' and cmd.args[1][1:] not in weight_keys:
            weight_keys.append(cmd.args[1][1:])
weight_offsets={}
count=0
for key in weight_keys:
    weight_offsets[key]=count
    count+=ddr.weight[key].numel()//8
header=['#ifndef SMOLLM2_FIRST_LAYER_KV_VECTORS_H','#define SMOLLM2_FIRST_LAYER_KV_VECTORS_H','#include "../first_layer_no_kv_board_probe/vectors.h"']
manifest={'checkpoint_revision':'93efa2f097d58c2a74874c7e644dbc9b0cee75a2','scope':'layer 0 prefill32 then decode1 at position 32; PL K/V DDR store and load','weight_words':count,'cases':{}}
captured=[]
hook=model.model.layers[0].register_forward_hook(lambda _m,_a,o: captured.append(o.detach().cpu().clone()))
with torch.inference_mode():
    prefill=model(torch.tensor([PREFILL_TOKENS]),use_cache=True,logits_to_keep=1)
    prefill_cache=prefill.past_key_values
    prefill_key=prefill_cache.layers[0].keys[0].clone()
    prefill_value=prefill_cache.layers[0].values[0].clone()
    decode=model(torch.tensor([DECODE_TOKENS]),past_key_values=prefill_cache,use_cache=True,logits_to_keep=1)
hook.remove()
assert len(captured)==2
machine=isa.Machine(ddr)
for i,(tokens,start) in enumerate(((PREFILL_TOKENS,0),(DECODE_TOKENS,32))):
    program=make_program(tokens,start)
    check_dispatcher_roles(program)
    machine.run(program)
    assert torch.equal(machine.get(0),captured[i][0]), isa.compare(
        f'layer0_{start}',machine.get(0),captured[i][0])
assert torch.equal(ddr.kv[0,'key'],decode.past_key_values.layers[0].keys[0].transpose(0,1))
assert torch.equal(ddr.kv[0,'value'],decode.past_key_values.layers[0].values[0].transpose(0,1))
manifest['interpreter_reference_exact'] = True
manifest['rtl_dispatcher_bank_roles_legal'] = True
for i,(name,tokens,start) in enumerate((('prefill32',PREFILL_TOKENS,0),('decode1',DECODE_TOKENS,32))):
    rows=len(tokens)
    embedding=torch.stack([ddr.embedding[token] for token in tokens])
    coeff=torch.cat((ddr.rope['cos'][start:start+rows], ddr.rope['sin'][start:start+rows]),dim=-1)
    header.append(c_words(f'kv_{name}_embedding_words',packed_words(embedding)))
    header.append(c_words(f'kv_{name}_coeff_words',packed_words(coeff)))
    header.append(c_bf16(f'kv_{name}_expected_layer0',captured[i][0]))
    # HF cache is [batch, kv_head, token, head_dim]. DDR row is [token, kv_head, head_dim].
    cache=decode.past_key_values
    key=(prefill_key if i==0 else cache.layers[0].keys[0]).transpose(0,1).contiguous()
    value=(prefill_value if i==0 else cache.layers[0].values[0]).transpose(0,1).contiguous()
    assert key.shape==(start+rows,3,64)
    header.append(c_bf16(f'kv_{name}_expected_key',key))
    header.append(c_bf16(f'kv_{name}_expected_value',value))
    entries=[]
    commands=[cmd for chunk in make_program(tokens,start).chunks for cmd in chunk]
    for cmd in commands:
        record=isa.wire_record(cmd,ddr)
        assert isa.wire_decode(record,ddr)==cmd
        source,offset=0xffffffff,0
        if cmd.op in ('DMA_LOAD','DMA_STORE'):
            key=cmd.args[1]
            if key[0]=='embedding': source,offset=i*2,cmd.args[2]*72
            elif key[0]=='rope': source,offset=i*2+1,0
            elif key[0]=='weight': source,offset=4,weight_offsets[key[1:]]
            elif key[0]=='kv': source,offset=(5 if key[2]=='key' else 6),(key[3]*24 if cmd.op=='DMA_STORE' else 0)
            else: raise AssertionError(key)
            record &= ~(((1<<32)-1)<<25)
        words=[(record>>(32*j))&0xffffffff for j in range(4)]
        entries.append('  {{'+','.join(f'0x{x:08x}u' for x in words)+f'}}, {source}u, {offset}u}},')
    header.append(f'static const isa_record_spec kv_{name}_program[{len(entries)}] = {{\n'+'\n'.join(entries)+'\n};')
    manifest['cases'][name]={'tokens':tokens,'start':start,'records':len(entries),'chunks':(len(entries)+15)//16,'key_values':(start+rows)*192}
header.append('#endif')
(OUT/'vectors.h').write_text('\n\n'.join(header)+'\n')
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(OUT/'vectors.h',manifest['cases'])
