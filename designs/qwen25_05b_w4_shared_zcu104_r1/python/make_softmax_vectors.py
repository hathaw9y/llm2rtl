from pathlib import Path
import json,hashlib
import torch
from safetensors.torch import load_file
import numeric as num
from make_rope_vectors import words
BASE=Path(__file__).resolve().parents[1]
def main():
 out=BASE/'evidence/softmax_run001';out.mkdir(exist_ok=False);torch.manual_seed(163)
 g=BASE/'evidence/isa_small_run002';records=json.loads((g/'command_golden.json').read_text());t=load_file(str(g/'command_golden.safetensors'));cases=[]
 for r in records:
  c=r['command']
  if c['opcode']==6:
   key=r['case'];m,n=c['m'],c['n'];x=t[f'{key}.before.bank18'].view(torch.float32).reshape(m,1024)[:,:n];y=t[f'{key}.after.bank21'].view(torch.bfloat16).reshape(m,1024)[:,:n];cases.append((x,y,c['position'],'actual ISA Softmax'))
 for m,n in [(1,1),(16,17),(1,1024),(16,1024)]:
  x=torch.randn(m,n)*40
  if n==17:x[:,16]=1e4 # forbidden to early rows; exercise causal max exclusion
  cases.append((x,num.softmax(x,n-m),n-m,'tail/maximum causal fixture'))
 for i,(x,y,p,name) in enumerate(cases):
  src=torch.zeros(x.shape[0],1024);dst=torch.zeros(x.shape[0],1024,dtype=torch.bfloat16);src[:,:x.shape[1]]=x;dst[:,:x.shape[1]]=y
  words(out/f'{i}_src.mem',src);words(out/f'{i}_expected.mem',dst)
 (out/'headers.txt').write_text(''.join(f'{x.shape[0]} {x.shape[1]} {p}\n' for x,_,p,_ in cases))
 (out/'manifest.json').write_text(json.dumps({'cases':[{'m':x.shape[0],'n':x.shape[1],'position':p,'origin':name} for x,_,p,name in cases],'numeric_sha256':hashlib.sha256((BASE/'python/numeric.py').read_bytes()).hexdigest()},indent=2)+'\n')
if __name__=='__main__':main()
