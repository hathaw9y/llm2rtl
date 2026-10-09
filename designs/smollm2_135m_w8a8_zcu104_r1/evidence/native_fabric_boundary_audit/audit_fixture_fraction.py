#!/usr/bin/env python3
"""Fresh exact-rational payload check without interpreter/exact_numeric imports."""
import hashlib,json,pathlib,struct
from fractions import Fraction as F
H=pathlib.Path(__file__).resolve().parent;D=H.parents[1];P=D/'tb/fabric_vectors/pingpong_quant_gemm'
def rne(v):
 n,d=v.numerator,v.denominator;q,r=divmod(n,d);return q+int(2*r>d or (2*r==d and q&1))
def decode(b):
 sign=-1 if b>>31 else 1;e=b>>23&255;m=b&0x7fffff
 assert e!=255
 return sign*F(m if e==0 else m+(1<<23))*F(2)**(-149 if e==0 else e-150)
def f32(v):
 sign=int(v<0);v=abs(v)
 if not v:return sign<<31
 e=v.numerator.bit_length()-v.denominator.bit_length()
 if v<F(2)**e:e-=1
 if e<-126:
  m=rne(v/F(2)**-149);return (sign<<31)|m
 m=rne(v/F(2)**(e-23))
 if m==(1<<24):e+=1;m>>=1
 assert e<=127
 return (sign<<31)|((e+127)<<23)|(m-(1<<23))
def bf16_from32(b):
 low=b&65535;upper=b>>16;return (upper+int(low>32768 or (low==32768 and upper&1)))&65535
sha=lambda x:hashlib.sha256(x).hexdigest()
m=json.loads((P/'manifest.json').read_text());checks=[]
for asset in m['assets']:
 data=(P/(asset['name']+'.bin')).read_bytes();assert len(data)==asset['bytes'] and sha(data)==asset['sha256']
for p,h in m['oracle_sources'].items():assert sha((D/p).read_bytes())==h
act=list(struct.unpack('<576H',(P/'activation.bin').read_bytes()));x=[decode(v<<16) for v in act]
s=f32(max(map(abs,x))/127);assert s!=0
q=[]
for value in x:
 quotient=decode(f32(value/decode(s)));n=rne(abs(quotient))*(-1 if quotient<0 else 1);q.append(max(-127,min(127,n)))
actual_q=bytes(v&255 for v in q);scale=struct.pack('<4I',s,0,0,0)
assert actual_q==(P/'quantized_a.bin').read_bytes();assert scale==(P/'activation_scale.bin').read_bytes()
checks.extend([{'asset':'quantized_a','bytes':len(actual_q),'sha256':sha(actual_q)},{'asset':'activation_scale','bytes':len(scale),'sha256':sha(scale)}])
for wname,outname in [('weight_b3','output_b5'),('weight_b15','output_b6')]:
 raw=(P/(wname+'.bin')).read_bytes();weights=[v if v<128 else v-256 for v in raw]
 scales=struct.unpack('<12I',(P/('scale_'+wname.split('_')[1]+'.bin')).read_bytes());results=[]
 for n in range(192):
  dot=sum(q[k]*weights[n*576+k] for k in range(576));combined=f32(decode(s)*decode(scales[n//16]));value=f32(decode(f32(F(dot)))*decode(combined));results.append(bf16_from32(value))
 output=struct.pack('<192H',*results);assert output==(P/(outname+'.bin')).read_bytes()
 checks.append({'asset':outname,'bytes':len(output),'sha256':sha(output)})
report={'status':'PASS','scope':'Independent Fraction oracle and immutable asset/reference identity only; no RTL execution or concurrency claim','manifest_sha256':sha((P/'manifest.json').read_bytes()),'numeric_checks':checks,'input_assets':5,'records':len((P/'program.hex').read_text().splitlines())}
(H/'pingpong_fixture_fraction_audit.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
