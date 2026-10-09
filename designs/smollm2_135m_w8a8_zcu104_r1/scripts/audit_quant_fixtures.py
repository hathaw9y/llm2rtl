"""Read-only fixture audit with a separate plain Fraction numeric oracle."""
from pathlib import Path
from fractions import Fraction
from functools import lru_cache
import hashlib,json,struct,sys,gzip
R=Path(__file__).resolve().parents[1];O=R/'evidence/independent_quant_executor_audit';O.mkdir(exist_ok=True)
sys.path.insert(0,str(R/'scripts'));from isa_codec import decode,validate_command
def sha(b):return hashlib.sha256(b).hexdigest()
def read(p):return b''.join(int(x,16).to_bytes(16,'little') for x in p.read_text().splitlines())
def power(e):return Fraction(1<<e) if e>=0 else Fraction(1,1<<-e)
@lru_cache(None)
def value(bits,p):
    e=(bits>>p)&255;f=bits&((1<<p)-1);assert e!=255
    v=Fraction(f if e==0 else (1<<p)+f)*power((-126 if e==0 else e-127)-p)
    return -v if bits>>(p+8) else v
def rne(v):
    n,d=v.numerator,v.denominator;q,rem=divmod(n,d)
    return q+int(2*rem>d or (2*rem==d and q&1))
def bits(v,p,signzero=0):
    sign=int(v<0) if v else signzero
    v=abs(v)
    if not v:return sign<<(p+8)
    e=v.numerator.bit_length()-v.denominator.bit_length()
    if v<power(e):e-=1
    if e < -126:
        mant=rne(v/power(-126-p))
        return (sign<<(p+8))|mant
    mant=rne(v/power(e-p))
    if mant==(1<<(p+1)):mant>>=1;e+=1
    if e>127:return (sign<<(p+8))|(255<<p)
    return (sign<<(p+8))|((e+127)<<p)|(mant-(1<<p))
@lru_cache(None)
def quant(x,scale,unsigned):
    q=bits(value(x,7)/value(scale,23),23,x>>15)
    if (q>>23)&255==255:return 0 if unsigned and q>>31 else (129 if q>>31 else 127)
    v=min(Fraction(127),max(Fraction(0 if unsigned else -127),value(q,23)))
    return ((-1 if v<0 else 1)*rne(abs(v)))&255
@lru_cache(None)
def dequant(x,scale):
    x=x-256 if x>=128 else x;assert x!=-128
    fp=bits(Fraction(x)*value(scale,23),23,int(x<0));assert (fp>>23)&255!=255
    bf=bits(value(fp,23),7,fp>>31);assert (bf>>7)&255!=255
    return bf
def u32(data):return list(struct.unpack('<'+'I'*(len(data)//4),data))
def u16(data):return list(struct.unpack('<'+'H'*(len(data)//2),data))
manifest=json.loads((R/'tb/quant_executor_vectors/manifest.json').read_text())
golden=json.loads((R/'verification/tensor_golden/manifest.json').read_text())
goldens={v['command_id']:v for v in golden['vectors']}
results=[]
for case in manifest['cases']:
    p=R/case['path'];raw=(p/'case.json').read_bytes();assert sha(raw)==case['metadata_sha256'];c=json.loads(raw)
    wire=validate_command(int(c['hex128'],16));f=wire['fields'];op=wire['opcode'];rows=f['m_count'];mode=f['mode']
    banks=[read(p/b['initial_file']) for b in c['banks']]
    for i,b in enumerate(c['banks']):
        assert len(banks[i])==b['capacity_bytes'] and sha(banks[i])==b['initial_sha256']
        assert b['descriptor']['generation']==c['generations'][i]
    assert list(wire['banks'])==[b['bank'] for b in c['banks']]
    expected=read(p/'expected.hex');mask=read(p/'expected_write_mask.hex');assert sha(expected)==c['expected_sha256']
    assert set(mask)<={0,1} and sum(mask)==c['expected_write_bytes']
    assert all(x==0xa5 for x,m in zip(expected,mask) if not m)
    assert c['producer_generation']==c['generations'][2]+1 and c['producer_rows']==rows
    static=op=='QUANTIZE' and mode in (2,3)
    roles=(24,0,25) if op=='DEQUANTIZE' else (21,22 if static else 0,23)
    assert [b['descriptor']['owner'] for b in c['banks']]==list(roles)
    assert c['cmd_b7_static_valid']==int(static)
    if static:assert c['banks'][1]['descriptor']['position']==777 and c['banks'][1]['descriptor']['data_valid']==0
    else:assert c['banks'][1]['descriptor']['present']==0 and c['generations'][1]==0
    if op=='DEQUANTIZE':
        count=rows*576;out=[]
        for i,x in enumerate(banks[0][:count]):
            row=i//576;lane=(c['cmd_embedding_lanes']>>(row*2))&3;assert c['cmd_embedding_lane_valid']>>row&1
            scale=int.from_bytes(banks[0][294912+row*16+lane*4:294912+row*16+lane*4+4],'little')
            assert scale>>31==0 and 0<scale<0x7f800000
            out.append(dequant(x,scale))
        data=struct.pack('<'+'H'*len(out),*out);scales=b'';scaleoff=0
    else:
        groups=(rows+15)//16;heads=1 if mode==0 else (9 if mode in (1,4) else 3)
        stride=f['k'] if mode==0 else (64 if mode!=4 else (f['kv_len']+15)//16*16)
        width=heads*stride;src=u16(banks[0][:c['banks'][0]['descriptor']['rows']*width*2])
        src=src[f['m_start']*width:(f['m_start']+rows)*width];out=bytearray(rows*width);scalevalues=[]
        for head in range(heads):
            ngroups=groups if mode in (0,1,4) else (1 if mode==2 else 4)
            for g in range(ngroups):
                if mode in (0,1,4):
                    ix=[r*width+head*stride+d for r in range(g*16,min(rows,(g+1)*16)) for d in range(stride) if mode!=4 or d<f['kv_len'] and d<=f['query_start']+r]
                    maximum=max((max(value(src[i],7),Fraction(0)) if mode==4 else abs(value(src[i],7)) for i in ix),default=Fraction(0))
                    scale=bits(maximum/Fraction(127),23) if maximum else 0x3f800000
                else:
                    off=4096+f['layer']*64+(head*4 if mode==2 else 16+(head*4+g)*4)
                    scale=int.from_bytes(banks[1][off:off+4],'little');assert scale>>31==0 and 0<scale<0x7f800000
                    ix=[r*width+head*stride+d for r in range(rows) for d in (range(64) if mode==2 else range(g*16,(g+1)*16))]
                scalevalues.append(scale)
                for i in ix:out[i]=quant(src[i],scale,mode==4)
        data=bytes(out);scales=struct.pack('<'+'I'*len(scalevalues),*scalevalues);scales+=bytes((-len(scales))%16)
        scaleoff=18432 if mode==1 else 196608 if static else 294912
    assert expected[:len(data)]==data and all(mask[:len(data)])
    if scales:assert expected[scaleoff:scaleoff+len(scales)]==scales and all(mask[scaleoff:scaleoff+len(scales)])
    assert sum(mask)==len(data)+len(scales)
    if c['golden_command_id'] is not None:
        v=goldens[c['golden_command_id']];assert c['hex128']==v['hex128']
        assert data==gzip.decompress((R/'verification/tensor_golden'/v['outputs']['data']['file']).read_bytes())
        if scales:assert scales==gzip.decompress((R/'verification/tensor_golden'/v['outputs']['scale']['file']).read_bytes())
    results.append({'case':c['name'],'status':'PASS_STRUCTURE_AND_INDEPENDENT_FRACTION_ORACLE','selected_bytes':len(data)+len(scales)})
(O/'fixture_audit.json').write_text(json.dumps({'status':'PASS','manifest_sha256':sha((R/'tb/quant_executor_vectors/manifest.json').read_bytes()),'count':len(results),'cases':results,'oracle':'Separate plain Fraction decode/RNE/divide/multiply; exact_numeric implementation not used'},indent=2)+'\n')
print('QUANT_FIXTURE_AUDIT_PASS',len(results))
