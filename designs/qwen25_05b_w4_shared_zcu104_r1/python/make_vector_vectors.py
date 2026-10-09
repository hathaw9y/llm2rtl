import json
from pathlib import Path
import torch
from safetensors.torch import load_file
import numeric as num
BASE=Path(__file__).resolve().parents[1]
def words(path,raw):
    data=raw.contiguous().view(torch.uint8).flatten().tolist()
    if len(data)%16:raise ValueError('unaligned fixture')
    path.write_text(''.join(f'{int.from_bytes(bytes(data[i:i+16]),"little"):032x}\n' for i in range(0,len(data),16)))
def padded(x):
    raw=x.contiguous().view(torch.uint8).reshape(x.shape[0],-1)
    stride=(raw.shape[1]+15)//16*16
    out=torch.zeros((x.shape[0],stride),dtype=torch.uint8);out[:,:raw.shape[1]]=raw
    return out
def main():
    out=BASE/'evidence/vector_run001';out.mkdir(exist_ok=False);records=[]
    golden=BASE/'evidence/isa_small_run002'
    cases=json.loads((golden/'command_golden.json').read_text());tensors=load_file(str(golden/'command_golden.safetensors'))
    for case in cases:
        c=case['command']
        if c['opcode']!=7:continue
        key=case['case'];a=str(c['a']);b=str(c['b']);dst=str(c['c'])
        ad=case['before'][a];bd=case['before'].get(b,{'n':0});dd=case['after'][dst]
        records.append({'mode':c['mode'],'m':c['m'],'n':c['n'],'src_m':ad['m'],'src_n':ad['n'],'b_n':bd['n'] if c['mode']<4 else 0,
                        'dst_m':dd['m'],'dst_n':dd['n'],'row':c['row'],'col':c['col'],'insert':int(bool(c['flags']&128)),
                        'begin':int(bool(c['flags']&64)),'a':c['a'],'b':c['b'],'dst':c['c'],
                        'src':tensors[f'{key}.before.bank{a}'],'second':tensors[f'{key}.before.bank{b}'] if c['mode']<4 else torch.zeros(16,dtype=torch.uint8),
                        'initial':tensors.get(f'{key}.before.bank{dst}',torch.zeros(dd['m']*dd['stride'],dtype=torch.uint8)),
                        'expected':tensors[f'{key}.after.bank{dst}'],'origin':'fresh full-model ISA '+key})
    torch.manual_seed(517)
    for mode in [0,1,2,3,4]:
        m=16;n=896 if mode in (1,3) else 128
        a=(torch.randn(m,n)*2).to(torch.bfloat16);b=(torch.randn(m if mode!=0 else 1,n)*.25).to(torch.bfloat16)
        if mode==0:
            a=a.float();result=num.bf16(num.add(a,b));bank_a=18;bank_b=22;dst=19
        elif mode==1:result=num.bf16(num.add(a,b));bank_a=0;bank_b=1;dst=3
        elif mode==2:result=num.silu_mul(a,b);bank_a=19;bank_b=20;dst=6
        elif mode==3:
            q,s=num.quantize(a);result=num.dequant(q,s);a=num.pack(q);b=s;bank_a=7;bank_b=8;dst=0
        else:a=a.float();result=num.bf16(a);b=torch.zeros((1,8),dtype=torch.bfloat16);bank_a=11;bank_b=0;dst=19
        records.append({'mode':mode,'m':m,'n':n,'src_m':m,'src_n':n,'b_n':b.shape[1] if mode<4 else 0,
                        'dst_m':m,'dst_n':n,'row':0,'col':0,'insert':0,'begin':1,'a':bank_a,'b':bank_b,'dst':dst,
                        'src':padded(a),'second':padded(b),'initial':padded(torch.zeros_like(result)),
                        'expected':padded(result),'origin':'maximum query-tile fixture'})
    # Last head extraction / insertion with nonzero semantic selectors and preserved neighbours.
    source=torch.randn(16,896).to(torch.bfloat16)
    records.append({'mode':5,'m':1,'n':64,'src_m':16,'src_n':896,'b_n':0,'dst_m':1,'dst_n':64,'row':15,'col':832,'insert':0,'begin':1,'a':0,'b':0,'dst':6,
                    'src':padded(source),'second':torch.zeros(16,dtype=torch.uint8),'initial':padded(torch.zeros(1,64,dtype=torch.bfloat16)),
                    'expected':padded(source[15:16,832:]),'origin':'last row/head extract'})
    source=torch.randn(16,64).to(torch.bfloat16);initial=torch.full((16,896),3.25,dtype=torch.bfloat16);expected=initial.clone();expected[:,832:]=source
    records.append({'mode':5,'m':16,'n':64,'src_m':16,'src_n':64,'b_n':0,'dst_m':16,'dst_n':896,'row':0,'col':832,'insert':1,'begin':0,'a':19,'b':0,'dst':0,
                    'src':padded(source),'second':torch.zeros(16,dtype=torch.uint8),'initial':padded(initial),
                    'expected':padded(expected),'origin':'insert preserves previously assembled regions'})
    headers=[];manifest=[]
    for i,r in enumerate(records):
        for key in ['src','second','initial','expected']:words(out/f'{i}_{key}.mem',r[key])
        sw=r['src'].numel()//16;bw=r['second'].numel()//16;dw=r['expected'].numel()//16
        fields=[r[k] for k in ['mode','m','n','src_m','src_n','b_n','dst_m','dst_n','row','col','insert','begin','a','b','dst']]+[sw,bw,dw]
        headers.append(' '.join(map(str,fields))+'\n');manifest.append({k:v for k,v in r.items() if k not in ['src','second','initial','expected']})
    (out/'headers.txt').write_text(''.join(headers));(out/'manifest.json').write_text(json.dumps({'cases':manifest},indent=2)+'\n')
    print(len(records))
if __name__=='__main__':main()
