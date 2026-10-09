"""ISA programs and packed payloads from frozen independent numerical/ISA references."""
import json,random,sys
from fractions import Fraction
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'reference'))
from quantizer_reference import encode_fp32,quantize_row
from isa_encoder import encode,quantize_program

def write_isa_vectors(out):
    rows=[]
    for count in [1,13,32,33,256]:
        for kind in ['zero','fractional','scaled']:
            values=[0x80000000 if i%2 else 0 for i in range(count)] if kind=='zero' else [encode_fp32(Fraction((i%15)-7,2)*(1 if kind=='fractional' else Fraction(321,8))) for i in range(count)]
            rows.append({'name':f'{kind}_{count}','values':values,**quantize_row(values)})
    rng=random.Random(3220610)
    for case in range(10):
        count=rng.choice([1,13,32,33,256]);values=[(rng.getrandbits(1)<<31)|(rng.randint(110,140)<<23)|rng.getrandbits(23) for _ in range(count)]
        rows.append({'name':f'random_{case}','values':values,**quantize_row(values)})
    for count in [1,13,33,256]:
        values=[encode_fp32(1)]*count;values[-1]=0x7fc00123
        rows.append({'name':f'nonfinite_{count}','values':values,**quantize_row(values)})
    input_words=[];output_words=[];metadata=[];program=[]
    for row in rows:
        count=len(row['values']);metadata.append((count<<17)|(row['error']<<16)|row['scale']);program+=quantize_program(count)
        # Poison every unused lane: a tail-lane overread becomes a visible error.
        padded=row['values']+[0x7fc0dead]*(256-count)
        input_words.extend(sum(padded[i+j]<<(32*j) for j in range(4)) for i in range(0,256,4))
        q=row['quantized']+[0]*(256-len(row['quantized']))
        output_words.extend(sum(q[i+j]<<(4*j) for j in range(32)) for i in range(0,256,32))
    bad=[
        encode(3,0,0,2,count=13,validate=False),encode(3,0,1,0,count=13,validate=False),encode(3,0,1,1,count=13,validate=False),
        encode(3,0,1,2,count=0,validate=False),encode(3,0,1,2,count=257,validate=False),
        encode(3,3,1,2,count=13,validate=False),encode(3,0,1,2,count=13,local_offset=1,validate=False),
        encode(3,0,1,2,count=13,axi_address=1,validate=False),encode(7,0,1,2,count=13,validate=False)]
    for name,values,width in [('isa_inputs.hex',input_words,32),('isa_outputs.hex',output_words,32),('isa_metadata.hex',metadata,8),('isa_programs.hex',program,32),('isa_bad_programs.hex',bad,32)]:
        (out/name).write_text('\n'.join(f'{value:0{width}x}' for value in values)+'\n')
    (out/'isa_reference_rows.json').write_text(json.dumps({'row_count':len(rows),'rows':rows,'bad_commands':bad},indent=2)+'\n')
    return len(rows),len(bad)
