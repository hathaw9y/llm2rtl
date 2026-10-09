import sys,json,random,math,pathlib
BASE=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(BASE/'reference'))
from fp32_reference import alu,bits,value
from exp_reference import exp_neg_bits

def generate(out):
    rng=random.Random(73419); vectors=[]
    directed=[0,0x80000000,1,2,3,0x7fffff,0x800000,0x800001,0x80800000,0x807fffff,0x3f800000,0xbf800000,0x3f000000,0x3f800001,0x40000000,0x7f7fffff,0xff7fffff,0x00800002,0x33800000,0x3f7fffff,0x7f800000,0x7fc00000]
    for op in (0,1,2,4):
        for a in directed:
            for b in directed:vectors.append((op,a,b))
    for a in [0,1,0xffffffff,0x80000000,0x7fffffff,0x01000001,0x01000003,*[rng.getrandbits(32) for _ in range(250)]]:vectors.append((3,a,0))
    for _ in range(8000):vectors.append((rng.choice([0,1,2,4]),rng.getrandbits(32),rng.getrandbits(32)))
    vectors.append((7,0,0))
    (out/'alu.hex').write_text(''.join(f'{(op<<97)|(a<<65)|(b<<33)|(alu(op,a,b)[0]<<1)|int(alu(op,a,b)[1]):025x}\n' for op,a,b in vectors))
    inputs=[bits(-80*i/8192) for i in range(8193)]
    # Integer and interpolation segment boundaries across the negative domain.
    for e in (0,-1,-7,-32,-64,-115):
        for i in range(257):
            x=(e+i/256)/math.log2(math.e)
            if -80<=x<=0:
                raw=bits(x);inputs.extend([raw,max(0,raw-1),raw+1])
    inputs.extend([0,0x80000000,1,0x80000001,0x807fffff,0x80800000,0xc2a00001,0xc2a00000,0xc29fffff,0x3f800000,0x7f800000,0xff800000,0x7fc00000])
    worst=0;worst_input=0; exp_vectors=[]
    for raw in inputs:
        try:expected=exp_neg_bits(raw);error=0
        except ValueError:expected=0;error=1
        x=value(raw)
        if not error and -80<=x<=0:
            rel=abs(value(expected)/math.exp(x)-1)
            if rel>worst:worst=rel;worst_input=raw
            assert rel<=1e-5,(x,rel)
        exp_vectors.append((raw,expected,error))
    (out/'exp.hex').write_text(''.join(f'{(a<<33)|(b<<1)|e:017x}\n' for a,b,e in exp_vectors))
    result={'alu_cases':len(vectors),'exp_cases':len(exp_vectors),'exp_max_relative_error':worst,'exp_worst_input':f'{worst_input:08x}','seed':73419}
    (out/'vectors.json').write_text(json.dumps(result,indent=2)+'\n');return result
