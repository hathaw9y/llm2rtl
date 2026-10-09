import json,hashlib
from pathlib import Path
import torch
from safetensors.torch import load_file
import numeric as num
from prepare import RESEARCH
BASE=Path(__file__).resolve().parents[1]
def words(path,x):
    raw=x.contiguous().view(torch.uint8).flatten().tolist()
    path.write_text(''.join(f'{int.from_bytes(bytes(raw[i:i+16]),"little"):032x}\n' for i in range(0,len(raw),16)))
def main():
    torch.manual_seed(20261006)
    out=BASE/'evidence/rope_run001';out.mkdir(exist_ok=False)
    table=next(iter(load_file(str(RESEARCH/'rope_table_candidate/table.safetensors')).values())).reshape(1024,128)
    cases=[]
    for i,(m,h,position) in enumerate([(1,2,0),(1,14,1023),(16,2,1008),(16,14,1008)]):
        x=(torch.randn(m,h*64)*2).to(torch.bfloat16);t=table[position:position+m];gold=num.rope(x,t,h)
        words(out/f'{i}_src.mem',x);words(out/f'{i}_param.mem',t);words(out/f'{i}_expected.mem',gold)
        cases.append({'case':i,'m':m,'heads':h,'position':position,'words':m*h*8})
    (out/'cases.json').write_text(json.dumps({'cases':cases,'numeric_sha256':hashlib.sha256((BASE/'python/numeric.py').read_bytes()).hexdigest()},indent=2)+'\n')
if __name__=='__main__':main()
