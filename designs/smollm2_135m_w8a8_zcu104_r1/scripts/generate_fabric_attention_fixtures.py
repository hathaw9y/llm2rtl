"""Offline prepared INT8 QK/PV connectivity fixtures; no softmax/calibration."""
import hashlib,json
from fractions import Fraction
from pathlib import Path
from isa_codec import encode
from isa_interpreter import Interpreter,DDR,pack32,PROFILES
import exact_numeric as num
D=Path(__file__).resolve().parents[1]
for length in [1,33,1024]:
 O=D/f'tb/fabric_vectors/attention_L{length}';O.mkdir(parents=True,exist_ok=True)
 ddr=DDR();assets=[];pad=(length+15)//16*16;query=16 if length==33 else length-1
 def save(name,address,data,kind='input'):
  if kind=='input':ddr.map(address,data,name)
  (O/(name+'.bin')).write_bytes(data)
  (O/(name+'.hex')).write_text(''.join(f'{int.from_bytes(data[j:j+16],"little"):032x}\n' for j in range(0,len(data),16)))
  assets.append(dict(name=name,address=address,bytes=len(data),kind=kind,sha256=hashlib.sha256(data).hexdigest()))
 def scales(n,den): return pack32([num.f32(Fraction(j+1,den)) for j in range(n)])+bytes((-n*4)%16)
 save('q_data',0x100000,bytes(((j*11)%255-127)&255 for j in range(576)))
 save('q_scale',0x110000,scales(9,1024))
 save('k_data',0x200000,bytes(((j*17+5)%255-127)&255 for j in range(length*192)))
 save('k_scale',0x240000,scales(3,2048))
 save('p_data',0x300000,bytes((h*13+t*7)%128 if t<length and t<=query else 0 for h in range(9) for t in range(pad)))
 save('p_scale',0x310000,scales(9,16384))
 save('v_data',0x400000,bytes(((j*29+3)%255-127)&255 for j in range(length*192)))
 save('v_scale',0x440000,scales(12,4096))
 ddr.map(0x500000,bytes([0xa5])*(9*pad*2),'score_output');ddr.map(0x510000,bytes([0xa5])*1152,'context_output')
 def cfg(bank,name,rows,cols,position=0):return encode('BANK_CONFIG',(bank,0,0),profile=PROFILES[name],rows=rows,cols=cols,position=position,generation=1)
 def load(bank,name,offset=0):
  a=next(a for a in assets if a['name']==name)
  return encode('DMA_LOAD',(bank,0,0),ddr_address=a['address'],byte_count=a['bytes'],local_byte_offset=offset)
 qk=[cfg(14,'Q_INT8',1,576),cfg(8,'K_current_or_cache_INT8',length,192),load(14,'q_data'),load(14,'q_scale',18432),load(8,'k_data'),load(8,'k_scale',196608),encode('ATTN_SCORE_INT8',(14,8,10),rows=1,kv_len=length,query_start=query),encode('DMA_STORE',(10,0,0),ddr_address=0x500000,byte_count=9*pad*2),0]
 pv=[cfg(13,'probability_INT8',1,length,query),cfg(9,'V_current_or_cache_INT8',length,192),load(13,'p_data'),load(13,'p_scale',294912),load(9,'v_data'),load(9,'v_scale',196608),encode('ATTN_VALUE_INT8',(13,9,11),rows=1,kv_len=length,query_start=query),encode('DMA_STORE',(11,0,0),ddr_address=0x510000,byte_count=1152),0]
 i=Interpreter(ddr)
 for name,program in [('qk',qk),('pv',pv)]:
  i.run(program);(O/f'program_{name}.hex').write_text(''.join(f'{r:032x}\n' for r in program))
 save('score_output',0x500000,ddr.read(0x500000,9*pad*2),'expected');save('context_output',0x510000,ddr.read(0x510000,1152),'expected')
 refs={str(p.relative_to(D)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [Path(__file__),D/'scripts/isa_interpreter.py',D/'scripts/exact_numeric.py',D/'scripts/isa_codec.py']}
 (O/'manifest.json').write_text(json.dumps(dict(scope='offline prepared INT8 QK/PV exact golden, no softmax/calibration/fullmodel claim',kv_len=length,query_start=query,rows=1,assets=assets,oracle_sources=refs,ledger=i.ledger,required_dynamic_checks=['ISA/native DMA preload only','shared real W8A8 core QK and PV dispatch','causal mask and padded tail exact zero','allocated wide tail reads permitted with ignored upper canary','exact BF16 DDR stores']),indent=2)+'\n')
 print(f'PASS prepared QK/PV fixture L{length} query{query}')
