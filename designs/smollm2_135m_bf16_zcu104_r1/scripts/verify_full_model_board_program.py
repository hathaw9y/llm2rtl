#!/usr/bin/env python3
"""Check PS C ISA words and 16-record chunks against full-model reference."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys
import torch
from transformers import AutoModelForCausalLM
D=Path(__file__).resolve().parents[1]
P=D/'full_model_board_probe'
sys.path.insert(0,str(D.parents[1]/'verification/prototypes'))
import smollm2_135m_isa_feasibility as isa
sys.path.insert(0,str(D/'scripts'))
from check_first_layer_kv_isa_candidate import check_dispatcher_roles
manifest=json.loads((P/'manifest.json').read_text())
subprocess.run(['gcc','-std=c11','-Wall','-Wextra','-Werror','-O2',
    'program.c','program_trace.c','-o','/tmp/smollm2_full_model_program_trace'],
    cwd=P,check=True)
trace_run=subprocess.run(['/tmp/smollm2_full_model_program_trace'],cwd=P,
                         check=True,capture_output=True,text=True)
actual_chunks={name:int(count) for name,count in re.findall(
    r'(prefill|decode) chunks=(\d+)',trace_run.stdout)}
assert set(actual_chunks)=={'prefill','decode'}
torch.set_num_threads(4)
model=AutoModelForCausalLM.from_pretrained(str(isa.CHECKPOINT),
    local_files_only=True,dtype=torch.bfloat16,attn_implementation='eager').eval()
ddr=isa.DDR(model,manifest['prefill_tokens'])
assert ddr.ddr_end_used-isa.DDR_START==manifest['ddr_bytes_used']
assert ddr.kv_base[0,'key']-isa.DDR_START==manifest['ddr_static_bytes']
assert hashlib.sha256((P/'ddr_static_bf16.bin').read_bytes()).hexdigest()==manifest['ddr_static_sha256']
machine=isa.Machine(ddr)
results={}
cache=None
for name,tokens,start in [('prefill',manifest['prefill_tokens'],0),
                          ('decode',manifest['decode_tokens'],32)]:
    p=isa.build_block(tokens,start,True)
    check_dispatcher_roles(p)
    ops=[cmd for chunk in p.chunks for cmd in chunk if cmd.op!='END']
    ops.append(isa.Cmd('FENCE'))
    expected=[f'{isa.wire_record(cmd,ddr):032x}' for cmd in ops]
    actual=(P/f'trace_{name}.hex').read_text().splitlines()
    assert actual==expected, next(((i,a,b) for i,(a,b) in enumerate(zip(actual,expected)) if a!=b),
                                  (len(actual),len(expected)))
    p.chunks=[ops[i:i+15]+[isa.Cmd('END')] for i in range(0,len(ops),15)]
    assert all(len(chunk)<=16 for chunk in p.chunks)
    with torch.inference_mode():
        if cache is None:
            reference=model(torch.tensor([tokens]),use_cache=True,logits_to_keep=1)
        else:
            reference=model(torch.tensor([tokens]),past_key_values=cache,
                            use_cache=True,logits_to_keep=1)
        cache=reference.past_key_values
        machine.run(p)
    assert torch.equal(ddr.logits,reference.logits[0]),isa.compare(
        name,ddr.logits,reference.logits[0])
    results[name]={'operations':len(ops),'minimum_16_record_chunks':len(p.chunks),
                   'app_chunks_with_layer_boundaries':actual_chunks[name],
                   'wire_records_exact':True,'interpreter_logits_exact':True,
                   'reference_top1':int(torch.argmax(reference.logits))}
(P/'program_verification.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results,indent=2))
