#!/usr/bin/env python3
"""Dense shape and chunk diagnostic using candidate Machine, actual BF16 tensors."""
import argparse,json,pathlib,sys
import torch
import torch.nn.functional as F
from t03_evaluate import namespace,PROTO
p=argparse.ArgumentParser();p.add_argument('--candidate-root',type=pathlib.Path,required=True);p.add_argument('--phase',choices=['public','hidden','all'],default='all');a=p.parse_args()
ns=namespace(a.candidate_root/PROTO);ns.update(torch=torch,F=F)
Cmd=ns['Cmd'];Program=ns['Program'];Machine=ns['Machine']
class DDR: kv={}
cases=0
for rows in ((1,2,8,16,31,32) if a.phase=='public' else (3,7,9,15,17,30) if a.phase=='hidden' else (1,2,3,7,8,9,15,16,17,30,31,32)):
 for k in (16,64):
  for first in (0,32-rows):
   # Exact integer power-of-two values distinguish semantic row and output columns.
   x=(2.0**(torch.arange(32)%4)).reshape(32,1).expand(32,k).to(torch.bfloat16).clone()
   w=(2.0**(torch.arange(192)%3)).reshape(192,1).expand(192,k).to(torch.bfloat16).clone()
   gold=(k*(2.0**((torch.arange(rows)+first)%4)).reshape(rows,1)*(2.0**(torch.arange(384)%3)).reshape(1,384)).to(torch.bfloat16)
   outputs=[]
   for split in (False,True):
    m=Machine(DDR());m.put(2,x.clone());m.put(3,w.clone());m.put(5,torch.full((2,16),-3,dtype=torch.bfloat16))
    p=Program();p.emit('GEMM',2,3,4,0,384,first,rows,k,192)
    if split:p.end()
    p.emit('GEMM',2,3,4,192,384,first,rows,k,192);p.end()
    m.run(p)
    assert torch.equal(m.get(4),gold),'numeric shape/row diagnostic'
    assert torch.equal(m.get(2),x) and torch.equal(m.get(3),w) and torch.all(m.get(5)==-3),'unrelated bank mutation'
    assert m.valid[4] and m.progress[4]==384 and m.chunks==(2 if split else 1),'chunk completion/state'
    outputs.append(m.get(4).view(torch.uint16).clone())
   assert torch.equal(*outputs),'chunk partition differs'
   cases+=1
# Attention command decoding regression is tested in wire gate; numerical attention common gate is separate.
print(json.dumps({'dense_numeric_cases':cases,'chunk_partitions':2,'bf16_exact':True,'untouched_banks':True}))
