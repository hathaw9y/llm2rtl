"""Offline multi-START exact projection/coverage fixture at model width576."""
import hashlib,json
from fractions import Fraction
from pathlib import Path
from isa_codec import encode
from isa_interpreter import Interpreter,DDR,pack16,pack32,PROFILES,ExecutionError
import exact_numeric as num
D=Path(__file__).resolve().parents[1];O=D/'tb/fabric_vectors/projection_fragments';O.mkdir(parents=True,exist_ok=True)
ddr=DDR();assets=[]
def asset(name,address,data,kind='input'):
 if kind=='input': ddr.map(address,data,name)
 (O/(name+'.bin')).write_bytes(data)
 (O/(name+'.hex')).write_text(''.join(f'{int.from_bytes(data[j:j+16],"little"):032x}\n' for j in range(0,len(data),16)))
 assets.append(dict(name=name,address=address,bytes=len(data),kind=kind,sha256=hashlib.sha256(data).hexdigest()))
asset('activation',0x100000,pack16([num.bf16(Fraction((j*23)%255-127,16)) for j in range(576)]))
ddr.map(0x700000,bytes([0xa5])*1152,'output')
def cfg(bank,name,rows,cols,gen): return encode('BANK_CONFIG',(bank,0,0),profile=PROFILES[name],rows=rows,cols=cols,generation=gen)
def dma(op,bank,address,count,offset=0):return encode(op,(bank,0,0),ddr_address=address,byte_count=count,local_byte_offset=offset)
records=[cfg(2,'norm_output',1,576,1),dma('DMA_LOAD',2,0x100000,1152),encode('QUANTIZE',(2,0,13),mode=0,m_count=1,k=576),cfg(4,'Q_BF16',1,576,1)]
for t in range(9):
 bank=(3,15)[t%2];gen=t//2+1;address=0x200000+t*0x10000;saddress=0x600000+t*0x100
 asset(f'weight_{t}',address,bytes(((j*19+t*31)%255-127)&255 for j in range(64*576)))
 asset(f'scale_{t}',saddress,pack32([num.f32(Fraction(t*4+j+1,4096)) for j in range(4)]))
 records.extend([cfg(bank,'weight_INT8',64,576,gen),dma('DMA_LOAD',bank,address,64*576),dma('DMA_LOAD',bank,saddress,16,294912),encode('GEMM_INT8',(13,bank,4),m_count=1,k=576,n_tile=64,n_total=576,n_start=t*64)])
records.append(dma('DMA_STORE',4,0x700000,1152))
fragments=[records[j:j+15]+[0] for j in range(0,len(records),15)]
i=Interpreter(ddr)
for n,f in enumerate(fragments):
 i.run(f);(O/f'program_{n}.hex').write_text(''.join(f'{r:032x}\n' for r in f))
asset('output',0x700000,ddr.read(0x700000,1152),'expected')
# New interpreters prove whole configured-tensor readiness, not only store span.
negative=[]
for name,missing,duplicate in [('missing_last_tile',8,False),('duplicate_first_tile',8,True)]:
 trial=Interpreter(ddr)
 work=records[:-1]
 # Work after initial4 records is grouped config/load/scale/GEMM.
 filtered=work[:4]
 for t in range(9):
  group=work[4+t*4:8+t*4]
  filtered.extend(group[:3])
  if t!=missing:filtered.append(group[3])
  if duplicate and t==0:filtered.append(group[3])
 for part,j in enumerate(range(0,len(filtered),15)):
  fragment=filtered[j:j+15]+[0]
  (O/f'{name}_program_{part}.hex').write_text(''.join(f'{r:032x}\n' for r in fragment))
  trial.run(fragment)
 (O/f'{name}_store.hex').write_text(f'{dma("DMA_STORE",4,0x700000,128):032x}\n{0:032x}\n')
 try:trial.step(dma('DMA_STORE',4,0x700000,128));raise AssertionError('incomplete full-tensor STORE accepted')
 except ExecutionError as e:negative.append(dict(name=name,expected='runtime data error04 before vendor command/native read',reference_error=str(e)))
refs={str(p.relative_to(D)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [Path(__file__),D/'scripts/isa_codec.py',D/'scripts/isa_interpreter.py',D/'scripts/exact_numeric.py']}
(O/'manifest.json').write_text(json.dumps(dict(scope='offline multi-START reference, RTL connectivity/coverage audited separately',fragments=[len(f) for f in fragments],tiles=9,assets=assets,negative=negative,oracle_sources=refs,ledger=i.ledger,required_dynamic_checks=['START preserves partial destination coverage','duplicate writes do not cover missing byte interval','incomplete whole-configured-tensor STORE rejected before vendor command/native read','exact full576 BF16 output']),indent=2)+'\n')
print('PASS offline projection fixture: 9 tiles/3 START fragments, 2 incomplete STORE negatives')
