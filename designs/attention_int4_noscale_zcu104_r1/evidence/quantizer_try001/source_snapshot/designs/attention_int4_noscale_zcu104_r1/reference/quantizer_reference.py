#!/usr/bin/env python3
"""Independent FP32/BF16/INT4 oracle: integers and Fraction only, no float arithmetic."""
from fractions import Fraction
import argparse,json,random
from pathlib import Path

def pow2(exponent):
    return Fraction(1<<exponent,1) if exponent>=0 else Fraction(1,1<<(-exponent))
def nearest_even(value):
    if value<0:return -nearest_even(-value)
    whole,remainder=divmod(value.numerator,value.denominator)
    twice=2*remainder
    return whole+(twice>value.denominator or (twice==value.denominator and whole%2==1))
def fp32_value(bits):
    exponent=(bits>>23)&255;mantissa=bits&0x7fffff
    if exponent==255:return None
    if exponent==0:return Fraction(0)
    value=(0x800000+mantissa)*pow2(exponent-127-23)
    return -value if bits>>31 else value

def bf16_value(bits):
    exponent=(bits>>7)&255;mantissa=bits&127
    if exponent==0:return mantissa*pow2(-126-7)
    assert exponent<255
    return (128+mantissa)*pow2(exponent-127-7)
def floor_log2(value):
    exponent=value.numerator.bit_length()-value.denominator.bit_length()
    if value<pow2(exponent):exponent-=1
    assert pow2(exponent)<=value<pow2(exponent+1)
    return exponent

def bf16_scale(value):
    assert value>0
    if value< pow2(-126):return 0x0080
    exponent=floor_log2(value)
    significand=nearest_even(value*pow2(7-exponent))
    if significand==256:significand=128;exponent+=1
    assert -126<=exponent<=127
    return ((exponent+127)<<7)|(significand-128)
def encode_fp32(value):
    """Directed-vector builder; rounding is independent of scale conversion."""
    sign=0x80000000 if value<0 else 0;value=abs(Fraction(value))
    if not value:return sign
    exponent=floor_log2(value)
    if exponent<-126:return sign|nearest_even(value*pow2(149))
    significand=nearest_even(value*pow2(23-exponent))
    if significand==(1<<24):significand=1<<23;exponent+=1
    assert exponent<=127
    return sign|((exponent+127)<<23)|(significand-(1<<23))
def quantize_row(values):
    decoded=[fp32_value(x) for x in values]
    if any(x is None for x in decoded):return {'error':1,'scale':0,'quantized':[]}
    maximum=max(map(abs,decoded),default=Fraction(0))
    scale=0x3f80 if maximum==0 else bf16_scale(maximum/7)
    scale_value=bf16_value(scale)
    quantized=[min(7,max(-7,nearest_even(x/scale_value)))&15 for x in decoded]
    assert 8 not in quantized
    return {'error':0,'scale':scale,'quantized':quantized}

def vectors(maximum,seed=180629):
    rows=[]
    def add(name,values):
        assert 0<len(values)<=maximum
        rows.append({'name':name,'values':values,**quantize_row(values)})
    def chunks(name,values):
        for start in range(0,len(values),maximum):add(f'{name}_{start}',values[start:start+maximum])
    add('signed_zero',[0,0x80000000])
    add('FTZ_subnormals',[1,0x7fffff,0x80000001,0x807fffff])
    add('minimum_normal_scale_clamp',[0x00800000,0x80800000,0x00ffffff])
    chunks('RNE_integer_halfway',[encode_fp32(Fraction(7)),*[encode_fp32(Fraction(k,2)) for k in range(-13,14,2)]])
    add('quant_tie_even_low',[encode_fp32(x) for x in [7,Fraction(1,2),Fraction(3,2),Fraction(5,2),Fraction(7,2),Fraction(9,2)]])
    add('quant_tie_even_negative',[encode_fp32(x) for x in [7,Fraction(-1,2),Fraction(-3,2),Fraction(-5,2),Fraction(-7,2),Fraction(-9,2)]])
    add('tiny_exp3_largest',[0x01ffffff,0x81ffffff,0x00800000])
    add('minnormal_threshold_ties',[encode_fp32(x*pow2(-126)) for x in [7,Fraction(3,2),Fraction(-3,2),Fraction(1,2),Fraction(-1,2)]])
    for delta in [-1,0,1]:add(f'minnormal_scale_boundary_{delta}',[0x01e00000+delta,0x81e00000+delta,0x00800000])
    add('extreme_FP32',[0x7f7fffff,0xff7fffff,0x00800000,0x80800000,0x3f800000])
    for bits in [0x0080,0x3f80,0x3f81,0x3fff,0x4000,0x7dff]:
        halfway=(bf16_value(bits)+bf16_value(bits+1))/2*7
        center=encode_fp32(halfway)
        for delta in [-1,0,1]:add(f'scale_halfway_{bits:04x}_{delta}',[center+delta,(center+delta)|0x80000000,encode_fp32(Fraction(1,2)) if bits>=0x3f80 else 0])
    for special in [0x7f800000,0xff800000,0x7fc00000,0x7f800001,0xffc12345]:
        add(f'nonfinite_{special:08x}',[encode_fp32(1),special,encode_fp32(-2),0])
    # Maximum-length and odd tails test tlast exactly once without nibble padding.
    for count in sorted(set([1,3,5,7,maximum])):
        if count<=maximum:add(f'tail_{count}',[encode_fp32(Fraction((i%15)-7,2)) for i in range(count)])
    rng=random.Random(seed)
    for index in range(100):
        count=rng.randint(1,maximum)
        values=[]
        for _ in range(count):
            exponent=rng.choice([0,1,2,63,124,125,126,127,128,129,190,253,254,rng.randint(1,254)])
            values.append((rng.randrange(2)<<31)|(exponent<<23)|rng.getrandbits(23))
        add(f'random_{index}',values)
    # Guarantee large tails and every finite exponent at the default capacity.
    chunks('all_normal_exponents',[((exponent&1)<<31)|(exponent<<23)|0x654321 for exponent in range(1,255)])
    return rows

def write_vectors(directory,maximum):
    directory.mkdir(parents=True,exist_ok=True);rows=vectors(maximum)
    slots=maximum
    inputs=[];outputs=[];meta=[]
    for row in rows:
        inputs+=row['values']+[0]*(slots-len(row['values']))
        outputs+=row['quantized']+[0]*(slots-len(row['quantized']))
        meta.append((len(row['values'])<<17)|(row['error']<<16)|row['scale'])
    for name,values,width in [('inputs.hex',inputs,8),('outputs.hex',outputs,1),('metadata.hex',meta,8)]:
        (directory/name).write_text('\n'.join(f'{x:0{width}x}' for x in values)+'\n')
    (directory/'reference_rows.json').write_text(json.dumps({'MAX_ELEMENTS':maximum,'row_count':len(rows),'rows':rows},indent=2)+'\n')
    # Basic independently obvious assertions guard the generator itself.
    assert nearest_even(Fraction(1,2))==0 and nearest_even(Fraction(3,2))==2
    assert quantize_row([encode_fp32(7),encode_fp32(Fraction(5,2))])['quantized']==[7,2]
    assert bf16_scale(Fraction(257,256))==0x3f80
    assert bf16_scale(Fraction(259,256))==0x3f82
    return len(rows)
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--out',required=True,type=Path);ap.add_argument('--max-elements',required=True,type=int);a=ap.parse_args();print(write_vectors(a.out,a.max_elements))
