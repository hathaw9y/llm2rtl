#!/usr/bin/env python3
"""Freeze BF16 checkpoint DDR image, address map, and full-model board goldens."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import sys
import torch
from transformers import AutoModelForCausalLM
D=Path(__file__).resolve().parents[1]
OUT=D/'full_model_board_probe'
OUT.mkdir(exist_ok=True)
sys.path.insert(0,str(D.parents[1]/'verification/prototypes'))
import smollm2_135m_isa_feasibility as isa
PREFILL=[(i*17+11)%49152 for i in range(32)]
DECODE=[555]
NAMES=('input_layernorm','post_attention_layernorm','q_proj','k_proj',
       'v_proj','o_proj','gate_proj','up_proj','down_proj')

def bf16_bytes(t):
    assert t.dtype==torch.bfloat16
    return t.contiguous().view(torch.uint16).numpy().tobytes()

def c_bits(name,t):
    bits=t.contiguous().view(torch.uint16).reshape(-1).tolist()
    return f'static const uint16_t {name}[{len(bits)}] = {{\n'+','.join(f'0x{int(x):04x}u' for x in bits)+'\n};\n'

torch.set_num_threads(4)
model=AutoModelForCausalLM.from_pretrained(str(isa.CHECKPOINT),
    local_files_only=True,dtype=torch.bfloat16,attn_implementation='eager').eval()
ddr=isa.DDR(model,PREFILL)
image=OUT/'ddr_static_bf16.bin'
with image.open('wb') as f:
    assert ddr.embedding_base==isa.DDR_START
    f.write(bf16_bytes(ddr.embedding))
    for key,weight in ddr.weight.items():
        if key[:2]==('final','lm_head'):
            assert ddr.weight_addr[key]==ddr.embedding_base+key[2]*576*2
            continue
        assert isa.DDR_START+f.tell()==ddr.weight_addr[key],(key,f.tell(),ddr.weight_addr[key])
        f.write(bf16_bytes(weight))
    assert isa.DDR_START+f.tell()==ddr.rope_base
    f.write(bf16_bytes(torch.cat((ddr.rope['cos'],ddr.rope['sin']),dim=-1)))
    assert isa.DDR_START+f.tell()==ddr.kv_base[0,'key']
static_bytes=image.stat().st_size

layer_outputs=[]
hooks=[]
for layer in model.model.layers:
    outputs=[]
    layer_outputs.append(outputs)
    hooks.append(layer.register_forward_hook(
        lambda _module,_args,output,target=outputs: target.append(output.detach().cpu().clone())))
with torch.inference_mode():
    prefill=model(torch.tensor([PREFILL]),use_cache=True,logits_to_keep=1)
    decode=model(torch.tensor([DECODE]),past_key_values=prefill.past_key_values,
                 use_cache=True,logits_to_keep=1)
for hook in hooks: hook.remove()
assert all(len(o)==2 for o in layer_outputs)
golden=['#ifndef SMOLLM2_FULL_MODEL_GOLDEN_H','#define SMOLLM2_FULL_MODEL_GOLDEN_H','#include <stdint.h>']
golden.append(c_bits('expected_prefill_logits',prefill.logits[0,0]))
golden.append(c_bits('expected_decode_logits',decode.logits[0,0]))
for label,idx,rows in (('prefill',0,32),('decode',1,1)):
    sample=torch.stack([o[idx][0,:,:16] for o in layer_outputs])
    assert sample.shape==(30,rows,16)
    golden.append(c_bits('expected_'+label+'_layer_first16',sample))
golden.append('#endif')
(OUT/'golden.h').write_text('\n'.join(golden)+'\n')

bases=[[ddr.weight_addr[layer,name,0] for name in NAMES] for layer in range(30)]
kv_bases=[[ddr.kv_base[layer,kind] for kind in ('key','value')] for layer in range(30)]
address=['#ifndef SMOLLM2_FULL_MODEL_ADDRESS_MAP_H','#define SMOLLM2_FULL_MODEL_ADDRESS_MAP_H','#include <stdint.h>',
 f'#define MODEL_DDR_BASE 0x{isa.DDR_START:08x}u',
 f'#define MODEL_DDR_STATIC_BYTES {static_bytes}u',
 f'#define MODEL_DDR_END 0x{ddr.ddr_end_used:08x}u',
 f'#define MODEL_EMBEDDING_BASE 0x{ddr.embedding_base:08x}u',
 f'#define MODEL_ROPE_BASE 0x{ddr.rope_base:08x}u',
 f'#define MODEL_FINAL_NORM 0x{ddr.weight_addr["final","norm",0]:08x}u',
 f'#define MODEL_LOGITS_BASE 0x{ddr.logits_base:08x}u',
 'enum { W_INPUT_NORM, W_POST_NORM, W_Q, W_K, W_V, W_O, W_GATE, W_UP, W_DOWN };',
 'static const uint32_t layer_weight_base[30][9] = {']
address += ['  {'+','.join(f'0x{x:08x}u' for x in row)+'},' for row in bases]
address += ['};','static const uint32_t layer_kv_base[30][2] = {']
address += ['  {'+','.join(f'0x{x:08x}u' for x in row)+'},' for row in kv_bases]
address += ['};','#endif']
(OUT/'address_map.h').write_text('\n'.join(address)+'\n')
manifest={
 'checkpoint_revision':'93efa2f097d58c2a74874c7e644dbc9b0cee75a2',
 'checkpoint_file_sha256':hashlib.sha256((isa.CHECKPOINT/'model.safetensors').read_bytes()).hexdigest(),
 'ddr_base':isa.DDR_START,'ddr_static_bytes':static_bytes,
 'ddr_bytes_used':ddr.ddr_end_used-isa.DDR_START,
 'ddr_static_sha256':hashlib.sha256(image.read_bytes()).hexdigest(),
 'prefill_tokens':PREFILL,'decode_tokens':DECODE,
 'prefill_reference_top1':int(torch.argmax(prefill.logits)),
 'decode_reference_top1':int(torch.argmax(decode.logits)),
 'scope':'30 layers, prefill32 then decode1 at position32, final norm and last-token logits',
 'physical_board_status':'not_run'}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({k:manifest[k] for k in ('ddr_static_bytes','ddr_bytes_used','prefill_reference_top1','decode_reference_top1')},indent=2))
