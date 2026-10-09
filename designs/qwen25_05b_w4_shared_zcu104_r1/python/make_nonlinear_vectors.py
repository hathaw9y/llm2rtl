from pathlib import Path
import json,hashlib
import torch
import numeric as num
BASE=Path(__file__).resolve().parents[1]
def main():
    out=BASE/'evidence/nonlinear_run001';out.mkdir(exist_ok=False)
    cases=[]
    for mode,fn,x in [(0,num.exp_nonpositive,torch.linspace(-88,0,2048)),
                      (1,num.reciprocal,torch.logspace(-37,37,2048)),
                      (2,num.rsqrt,torch.logspace(-37,37,2048))]:
        y=fn(x)
        for a,b in zip(x.view(torch.int32).tolist(),y.view(torch.int32).tolist()):
            cases.append((mode,a&0xffffffff,b&0xffffffff,0))
    for mode,x in [(0,0x3f800000),(0,0x7fc00000),(1,0),(1,0xbf800000),(2,0),(2,0x7f800000),(3,0x3f800000)]:cases.append((mode,x,0,1))
    (out/'vectors.mem').write_text(''.join(f'{((m<<65)|(x<<33)|(y<<1)|e):017x}\n' for m,x,y,e in cases))
    (out/'identity.json').write_text(json.dumps({'count':len(cases),'numeric_sha256':hashlib.sha256((BASE/'python/numeric.py').read_bytes()).hexdigest()},indent=2)+'\n')
if __name__=='__main__':main()
