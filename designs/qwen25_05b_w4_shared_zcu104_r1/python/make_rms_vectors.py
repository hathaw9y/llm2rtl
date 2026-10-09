from pathlib import Path
import json
import torch
from safetensors.torch import load_file
import numeric as num
from make_rope_vectors import words
BASE=Path(__file__).resolve().parents[1]
def main():
    out=BASE/'evidence/rmsnorm_run001';out.mkdir(exist_ok=False);torch.manual_seed(99)
    cases=[]
    g=BASE/'evidence/isa_small_run002';records=json.loads((g/'command_golden.json').read_text());t=load_file(str(g/'command_golden.safetensors'))
    r=next(c for c in records if c['command']['opcode']==4);key=r['case'];c=r['command'];m=c['m']
    cases.append((t[f'{key}.before.bank{c["a"]}'].view(torch.bfloat16).reshape(m,896),t[f'{key}.before.bank{c["b"]}'].view(torch.bfloat16).reshape(1,896),t[f'{key}.after.bank{c["c"]}'].view(torch.bfloat16).reshape(m,896),'actual ISA first RMSNorm'))
    for m,style in [(1,'ones'),(16,'zeros'),(16,'random'),(1,'large')]:
        x=torch.ones(m,896) if style=='ones' else torch.zeros(m,896) if style=='zeros' else torch.randn(m,896)*(1e10 if style=='large' else 3)
        x=x.to(torch.bfloat16);gamma=(.8+.25*torch.randn(1,896)).to(torch.bfloat16);cases.append((x,gamma,num.rmsnorm(x,gamma),style))
    for i,(x,gamma,y,name) in enumerate(cases):
        words(out/f'{i}_src.mem',x);words(out/f'{i}_param.mem',gamma);words(out/f'{i}_expected.mem',y)
    (out/'headers.txt').write_text(''.join(f'{x.shape[0]}\n' for x,_,_,_ in cases));(out/'manifest.json').write_text(json.dumps({'cases':[{'rows':x.shape[0],'origin':name} for x,_,_,name in cases]},indent=2)+'\n')
if __name__=='__main__':main()
