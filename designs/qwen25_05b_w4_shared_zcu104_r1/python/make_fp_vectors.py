"""Arithmetic RTL vectors from the pinned numeric policy, including FTZ/overflow."""
from pathlib import Path
import json,hashlib
import torch
import numeric as num
BASE=Path(__file__).resolve().parents[1]
def main():
    out=BASE/'evidence/fp32_run001';out.mkdir(exist_ok=False)
    torch.manual_seed(20261006)
    n=16384
    ab=torch.randint(0,1<<32,(n,2),dtype=torch.int64)
    special=[0,0x80000000,0x00000001,0x007fffff,0x00800000,0x00800001,0x3f800000,0xbf800000,0x7f7fffff,0xff7fffff,0x7f800000,0x7fc00000]
    for i,a in enumerate(special):
        for j,b in enumerate(special):ab[i*len(special)+j]=torch.tensor([a,b])
    a=ab[:,0].to(torch.int32).view(torch.float32);b=ab[:,1].to(torch.int32).view(torch.float32)
    multiplication=torch.arange(n)%2
    y=torch.where(multiplication.bool(),num.mul(a,b),num.add(a,b))
    error=(~torch.isfinite(a))|(~torch.isfinite(b))|(~torch.isfinite(y))
    bits=y.view(torch.int32).to(torch.int64)&0xffffffff
    with (out/'arithmetic.mem').open('w') as f:
        for i in range(n):
            word=(int(multiplication[i])<<97)|(int(ab[i,0])<<65)|(int(ab[i,1])<<33)|(int(bits[i])<<1)|int(error[i])
            f.write(f'{word:025x}\n')
    bf=num.bf16(a).view(torch.int16).to(torch.int64)&65535
    with (out/'bf16.mem').open('w') as f:
        for i in range(n): f.write(f'{((int(ab[i,0])<<16)|int(bf[i])):012x}\n')
    for name,table in [('exp2',num.EXP2),('reciprocal',num.RECIP),('rsqrt',num.RSQRT)]:
        (out/(name+'.mem')).write_text(''.join(f'{int(x)&0xffffffff:08x}\n' for x in table.view(torch.int32).tolist()))
    (out/'vector_identity.json').write_text(json.dumps({'count':n,'generator_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'numeric_sha256':hashlib.sha256((BASE/'python/numeric.py').read_bytes()).hexdigest()},indent=2)+'\n')
if __name__=='__main__':main()
