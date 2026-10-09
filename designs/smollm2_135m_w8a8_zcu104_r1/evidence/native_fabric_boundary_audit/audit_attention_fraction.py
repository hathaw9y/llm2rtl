#!/usr/bin/env python3
import json,struct
from audit_fixture_fraction import D,H,F,f32,decode,bf16_from32,sha
reports=[]
for length in [1,33,1024]:
 p=D/f'tb/fabric_vectors/attention_L{length}';m=json.loads((p/'manifest.json').read_text());pad=(length+15)//16*16;query=m['query_start']
 for asset in m['assets']:
  raw=(p/(asset['name']+'.bin')).read_bytes();assert len(raw)==asset['bytes'] and sha(raw)==asset['sha256']
 for ref,h in m['oracle_sources'].items():assert sha((D/ref).read_bytes())==h
 def ints(n):return [v if v<128 else v-256 for v in (p/(n+'.bin')).read_bytes()]
 def scales(n):
  raw=(p/(n+'.bin')).read_bytes();return struct.unpack('<'+'I'*(len(raw)//4),raw)
 q,k,prob,v=map(ints,['q_data','k_data','p_data','v_data']);qs,ks,ps,vs=map(scales,['q_scale','k_scale','p_scale','v_scale'])
 assert all(z>=0 for z in prob);score=[];context=[]
 for h in range(9):
  kh=h//3;combined=f32(decode(qs[h])*decode(ks[kh]));combined=f32(decode(combined)/8)
  for t in range(pad):
   if t>query or t>=length:score.append(0);continue
   dot=sum(q[h*64+d]*k[t*192+kh*64+d] for d in range(64));score.append(bf16_from32(f32(decode(f32(F(dot)))*decode(combined))))
  for d in range(64):
   dot=sum(prob[h*pad+t]*v[t*192+kh*64+d] for t in range(length));combined=f32(decode(ps[h])*decode(vs[kh*4+d//16]));context.append(bf16_from32(f32(decode(f32(F(dot)))*decode(combined))))
 for name,values in [('score_output',score),('context_output',context)]:
  raw=struct.pack('<'+'H'*len(values),*values);assert raw==(p/(name+'.bin')).read_bytes()
 reports.append({'kv_len':length,'query_start':query,'padded_length':pad,'manifest_sha256':sha((p/'manifest.json').read_bytes()),'score_sha256':sha((p/'score_output.bin').read_bytes()),'context_sha256':sha((p/'context_output.bin').read_bytes()),'qk_heads':9,'kv_heads':3,'pv_scale_groups_per_kv_head':4,'qk_causal_and_padding_zero':True})
result={'status':'PASS','scope':'Offline independent Fraction oracle and pinned asset checks only; actual ISA/DMA/native/compute fabric not yet tested','cases':reports}
(H/'attention_fixture_fraction_audit.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
