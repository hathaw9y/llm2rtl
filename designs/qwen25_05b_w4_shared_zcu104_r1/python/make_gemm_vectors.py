from pathlib import Path
import json,hashlib
import torch
from safetensors.torch import load_file
import numeric as num
from make_rope_vectors import words
BASE=Path(__file__).resolve().parents[1]
def main():
 out=BASE/'evidence/gemm_run001';out.mkdir(exist_ok=True);torch.manual_seed(227);torch.set_num_threads(2)
 g=BASE/'evidence/isa_small_run002';records=json.loads((g/'command_golden.json').read_text());t=load_file(str(g/'command_golden.safetensors'));cases=[]
 for r in records:
  c=r['command']
  if c['opcode']!=3:continue
  key=r['case'];a=t[f'{key}.before.bank{c["a"]}'];b=t[f'{key}.before.bank{c["b"]}'];s=t[f'{key}.before.bank8'] if c['mode']==0 else torch.zeros(128,dtype=torch.float32);d=t[f'{key}.before.bank{c["c"]}'] if not c['flags']&1 else torch.zeros_like(t[f'{key}.after.bank{c["c"]}']);y=t[f'{key}.after.bank{c["c"]}'];cases.append((c,a,b,s,d,y,'actual ISA GEMM'))
 for mode,m,n,k,init in [(0,16,128,128,1),(0,1,128,128,0),(1,16,17,64,1),(1,1,1024,64,1),(2,16,64,17,1),(2,1,64,1024,1)]:
  a=torch.randn(m,k).to(torch.bfloat16);s=torch.rand(128)*.2+.001
  if mode==0:
   q=torch.randint(-7,8,(n,k),dtype=torch.int8);b=num.pack(q);y=num.mul(num.dot(a,q.float()),s);d=torch.randn(m,n);y=num.add(torch.zeros_like(y) if init else d,y)
  elif mode==1:b=torch.randn(n,k).to(torch.bfloat16);y=num.dot(a,b);d=torch.zeros(m,1024)
  else:b=torch.randn(k,n).to(torch.bfloat16);y=num.dot(a,b.T);d=torch.zeros_like(y)
  if mode==2:ap=torch.zeros(m,1024,dtype=torch.bfloat16);ap[:,:k]=a;a=ap
  if mode==1:yp=torch.zeros(m,1024);yp[:,:n]=y;y=yp
  c=dict(mode=mode,m=m,n=n,k=k,flags=init,a=21 if mode==2 else 6,b=7 if mode==0 else 9 if mode==1 else 10,c=18 if mode==1 else 11)
  cases.append((c,a,b,s,d,y,'maximum/tail/group fixture'))
 for i,(c,a,b,s,d,y,name) in enumerate(cases):
  for label,x in [('act',a),('wgt',b),('scale',s),('initial',d),('expected',y)]:words(out/f'{i}_{label}.mem',x)
 headers=[]
 for c,a,b,s,d,y,name in cases:headers.append(f'{c["mode"]} {c["m"]} {c["n"]} {c["k"]} {int(bool(c["flags"]&1))} {a.numel()*a.element_size()//16} {b.numel()*b.element_size()//16} {s.numel()*s.element_size()//16} {y.numel()*y.element_size()//16}\n')
 (out/'headers.txt').write_text(''.join(headers));(out/'manifest.json').write_text(json.dumps({'cases':[dict(command=c,origin=name) for c,*_,name in cases],'numeric_sha256':hashlib.sha256((BASE/'python/numeric.py').read_bytes()).hexdigest()},indent=2)+'\n')
if __name__=='__main__':main()
