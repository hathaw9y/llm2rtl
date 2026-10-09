"""Offline exact ISA fixture; no DUT memory injection or runtime tensor math."""
import hashlib
import json
from fractions import Fraction
from pathlib import Path
from isa_codec import encode
from isa_interpreter import Interpreter, DDR, pack16, pack32, PROFILES
import exact_numeric as num
D = Path(__file__).resolve().parents[1]
O = D / 'tb/fabric_vectors/pingpong_quant_gemm'
O.mkdir(parents=True, exist_ok=True)
ddr = DDR()
inputs = {
 'activation': (0x100000, pack16([num.bf16(Fraction((i*37)%255-127,32)) for i in range(576)])),
 'weight_b3': (0x200000, bytes(((i*13+i//576*7)%255-127)&255 for i in range(192*576))),
 'weight_b15': (0x300000, bytes(((i*17+i//576*11)%255-127)&255 for i in range(192*576))),
 'scale_b3': (0x400000, pack32([num.f32(Fraction(i+1,1024)) for i in range(12)])),
 'scale_b15': (0x410000, pack32([num.f32(Fraction(13-i,2048)) for i in range(12)])),
}
for name,(addr,data) in inputs.items(): ddr.map(addr,data,name)
for name,addr in [('output_b5',0x500000),('output_b6',0x510000)]: ddr.map(addr,bytes([0xa5])*384,name)
i=Interpreter(ddr)
def cfg(bank,name,rows,cols):
 return encode('BANK_CONFIG',(bank,0,0),profile=PROFILES[name],rows=rows,cols=cols,generation=1)
def load(bank,name,offset=0):
 addr,data=inputs[name]
 return encode('DMA_LOAD',(bank,0,0),ddr_address=addr,local_byte_offset=offset,byte_count=len(data))
def gemm(w,c):
 return encode('GEMM_INT8',(13,w,c),m_count=1,k=576,n_tile=192,n_total=192)
records=[cfg(2,'norm_output',1,576),load(2,'activation'),
 encode('QUANTIZE',(2,0,13),mode=0,m_count=1,k=576),
 cfg(3,'weight_INT8',192,576),load(3,'weight_b3'),load(3,'scale_b3',294912),
 cfg(15,'weight_INT8',192,576),cfg(5,'K_BF16',1,192),cfg(6,'V_BF16',1,192),
 gemm(3,5),load(15,'weight_b15'),load(15,'scale_b15',294912),gemm(15,6),
 encode('DMA_STORE',(5,0,0),ddr_address=0x500000,byte_count=384),
 encode('DMA_STORE',(6,0,0),ddr_address=0x510000,byte_count=384),0]
i.run(records)
(O/'program.hex').write_text(''.join(f'{r:032x}\n' for r in records))
assets=[]
def save(name,data,addr=None,kind='input'):
 (O/(name+'.bin')).write_bytes(data)
 (O/(name+'.hex')).write_text(''.join(f'{int.from_bytes(data[j:j+16],"little"):032x}\n' for j in range(0,len(data),16)))
 assets.append(dict(name=name,kind=kind,address=addr,bytes=len(data),sha256=hashlib.sha256(data).hexdigest()))
for name,(addr,data) in inputs.items(): save(name,data,addr)
for name,addr in [('output_b5',0x500000),('output_b6',0x510000)]: save(name,ddr.read(addr,384),addr,'expected')
save('quantized_a',i.banks[13].bytes(),kind='expected')
save('activation_scale',i.banks[13].bytes('scale'),kind='expected')
refs={str(p.relative_to(D)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [D/'scripts/isa_interpreter.py',D/'scripts/exact_numeric.py',D/'scripts/isa_codec.py',Path(__file__)]}
manifest=dict(scope='offline exact tensor oracle; RTL AXIS/concurrency tested separately',records=16,assets=assets,oracle_sources=refs,ledger=i.ledger,required_dynamic_checks=['DMA writes to B15 overlap actual B3 GEMM work','no B3 payload write during B3 GEMM ownership','ISA-only command and DDR preload; no DUT native memory preload','exact BF16 stored output and FP32 activation scale'])
(O/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('PASS offline pingpong fixture: 16 ISA records, 2 exact BF16 outputs')
