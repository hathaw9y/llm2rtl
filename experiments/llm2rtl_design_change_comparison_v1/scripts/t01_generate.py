#!/usr/bin/env python3
"""Evaluator preparation only: deterministic inputs, then original RTL records golden."""
import json,random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]/'evaluator/t01'
def emit(path,values):
 words=[sum(v<<(16*j) for j,v in enumerate(values[i:i+8])) for i in range(0,len(values),8)] or [0]
 path.write_text(''.join(f'{w:032x}\n' for w in words));return len(words)
for suite,seed in [('public',101),('hidden',17019)]:
 d=ROOT/suite;d.mkdir(parents=True,exist_ok=True);rng=random.Random(seed);cases=[]
 def values(n):
  # Signs, unequal scales, zero/subnormal, cancellation, nontrivial BF16 mantissas.
  palette=[0,0x0001,0x3a81,0x3b80,0x3f01,0x3f80,0x3fc1,0x4003,0xba83,0xbf80,0xbfc3,0xc001]
  return [rng.choice(palette) for _ in range(n)]
 def add(label,op,banks,p,a,w,dcap,writes,err=0):
  i=len(cases);alen=emit(d/f'{i}_a.hex',a);wlen=emit(d/f'{i}_w.hex',w)
  cap=lambda b:{2:2304,3:36864,4:2304,8:24576,9:24576,10:36864,11:2304,12:6144}[b]
  cases.append(dict(id=i,label=label,opcode=op,banks=banks,payload=f'{p:028x}',acap=cap(banks[0]),wcap=cap(banks[1]),dcap=dcap,alen=alen,wlen=wlen,error=err,expected_elements=writes))
 def dense(m,n,k,ms=0,ns=3):
  nt=n+ns+3;p=(ns<<47)|(nt<<31)|(ms<<25)|(m<<19)|(k<<8)|n
  add(f'dense_m{m}_n{n}_k{k}_ms{ms}_ns{ns}',3,[2,3,12],p,values((m+ms)*k),values(n*k),6144,m*n)
 for j,m in enumerate([1,7,8,9,16,17,31,32]):dense(m,[1,7,16,17,191,192,17,7][j],64,ms=0 if m==32 else 1)
 for n in [1,7,16,17,191,192]:dense(9,n,16)
 dense(32,17,576);dense(1,192,1536);dense(9,1,1536)
 # Odd K exercises paired read unalignment; multiple internal K boundaries.
 dense(17,17,33,ms=1,ns=7)
 for op in [6,8]:
  for m,kv,start in [(8,9,0),(9,17,0),(17,31,0),(32,32,0),(1,33,32),(1,193,192)]:
   pad=(kv+7)//8*8;p=(start<<17)|(m<<11)|kv
   if op==6:
    a=values(m*576);w=values(kv*192);banks=[4,8,10];dcap=36864;count=m*9*pad
   else:
    a=values(m*9*pad);w=values(kv*192);banks=[10,9,11];dcap=2304;count=m*576
   add(f'{"score" if op==6 else "value"}_m{m}_kv{kv}_query{start}',op,banks,p,a,w,dcap,count)
 # Invalid commands must return one held error response and preserve all bytes.
 add('invalid_dense_m33',3,[2,3,12],(8<<31)|(33<<19)|(16<<8)|1,[0]*16,[0]*16,6144,0,1)
 add('invalid_score_query_plus_rows',6,[4,8,10],(32<<17)|(9<<11)|33,[0],[0],36864,0,1)
 (d/'cases.txt').write_text(''.join(f"{c['id']} {c['opcode']} {' '.join(map(str,c['banks']))} {c['payload']} {c['acap']} {c['wcap']} {c['dcap']} {c['alen']} {c['wlen']} {c['error']} {c['expected_elements']}\n" for c in cases))
 (d/'cases.json').write_text(json.dumps(cases,indent=2)+'\n')
print('Generated public and hidden inputs; exact golden requires evaluator baseline recording.')
