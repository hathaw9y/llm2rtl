"""Independent Python integer oracle, deterministic legal operands only."""
import json, random
from pathlib import Path
D=Path(__file__).resolve().parents[1]
rng=random.Random(831)
inputs=[];outputs=[];acc=[[0]*16 for _ in range(96)]
def issue(row,first,last,nv,kind='random'):
    a=[rng.randint(-127,127) for _ in range(16)]
    b=[[rng.randint(-127,127) for _ in range(16)] for _ in range(16)]
    if kind=='max': a=[127]*16;b=[[127]*16 for _ in range(16)]
    if kind=='negative': a=[-127]*16;b=[[127]*16 for _ in range(16)]
    if kind=='cancel': a=[127,-127]*8;b=[[127]*16 for _ in range(16)]
    tag=len(inputs)+123;scale=0x3f800000+(len(inputs)%23)
    dots=[sum(x*y for x,y in zip(a,b[n])) if n<nv else 0 for n in range(16)]
    acc[row]=[v if first else acc[row][n]+v for n,v in enumerate(dots)]
    def pack(vals,bits):return sum((v&((1<<bits)-1))<<(bits*i) for i,v in enumerate(vals))
    inputs.append(f'{pack(a,8):032x} {pack(sum(b,[]),8):0512x} {row:x} {int(first):x} {int(last):x} {nv:x} {tag:024x} {scale:08x}')
    if last:outputs.append(f'{pack(acc[row],32):0128x} {nv:x} {tag:024x} {scale:08x}')
for kind in ('max','negative','cancel'):
    for k in range(96):issue(0,k==0,k==95,16,kind)
# all96 contexts interleaved across full1536 K; many live product paths.
for k in range(96):
    for row in range(96):issue(row,k==0,k==95,1+(row%16))
for i in range(150):issue(i%96,True,True,1+i%16)
for k in range(64):issue(0,k==0,k==63,16)
E=D/'evidence/int8_dot_core';E.mkdir(parents=True,exist_ok=True)
(E/'inputs.txt').write_text('\n'.join(inputs)+'\n');(E/'expected.txt').write_text('\n'.join(outputs)+'\n')
(E/'vector_manifest.json').write_text(json.dumps({'seed':831,'inputs':len(inputs),'outputs':len(outputs),'independent_oracle':'Python arbitrary precision sum(x*y)','legal_maxK':1536,'no_reuse_of_isa_dot_backend':True},indent=2)+'\n')
print(len(inputs),len(outputs))
