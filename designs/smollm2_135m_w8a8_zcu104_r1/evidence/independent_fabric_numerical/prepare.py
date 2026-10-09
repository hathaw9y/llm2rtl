"""Independent external-only numerical audit environment. No DUT changes."""
from pathlib import Path
import hashlib,json,sys,shutil
HERE=Path(__file__).resolve().parent
DESIGN=HERE.parents[1]
ROOT=DESIGN.parents[1]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
manifest=DESIGN/'contracts/execution_fabric_module_manifest.json'
assert sha(manifest)=='38bb314c4c7347b8721a7b1f89258928ceb9a2ae923ba623444fb637c4d3c6bc'
m=json.loads(manifest.read_text())
for ref in m['refs'].values(): assert sha(ROOT/ref['path'])==ref['sha256'],ref
binding=json.loads((DESIGN/'contracts/execution_fabric_rtl_binding.json').read_text())
sys.path.insert(0,str(DESIGN/'scripts'))
from isa_codec import encode,validate_command,decode
pins={str(manifest.relative_to(ROOT)):sha(manifest)}
for suite in ['pingpong_quant_gemm','projection_fragments','attention_L1','attention_L33','attention_L1024']:
 src=DESIGN/'tb/fabric_vectors'/suite; dst=HERE/'prepared'/suite;dst.mkdir(parents=True,exist_ok=True)
 j=json.loads((src/'manifest.json').read_text());assets=[]
 for a in j['assets']:
  p=src/(a['name']+'.bin'); assert len(p.read_bytes())==a['bytes'] and sha(p)==a['sha256']
  pins[str(p.relative_to(ROOT))]=sha(p)
  a=dict(a)
  if a['address'] is None:
   a['address']={'quantized_a':0x520000,'activation_scale':0x530000}[a['name']]
  assets.append(a)
  (dst/(a['name']+'.bytehex')).write_text(''.join(f'{b:02x}\n' for b in p.read_bytes()))
 for ref,h in j['oracle_sources'].items():
  p=DESIGN/ref;assert sha(p)==h,(p,h);pins[str(p.relative_to(ROOT))]=h
 pins[str((src/'manifest.json').relative_to(ROOT))]=sha(src/'manifest.json')
 if suite=='pingpong_quant_gemm':
  programs=[src/'program.hex']
 elif suite=='projection_fragments':programs=[src/f'program_{i}.hex' for i in range(3)]
 else:programs=[src/'program_qk.hex',src/'program_pv.hex']
 prog=[]
 for p in programs:
  v=[int(l,16) for l in p.read_text().splitlines()];assert len(v)<=16
  for r in v:validate_command(r)
  prog.append(v+[0]*(16-len(v)));pins[str(p.relative_to(ROOT))]=sha(p)
 if suite=='pingpong_quant_gemm':
  v=[encode('DMA_STORE',banks=(13,0,0),byte_count=576,ddr_address=0x520000,local_byte_offset=0),encode('DMA_STORE',banks=(13,0,0),byte_count=16,ddr_address=0x530000,local_byte_offset=294912)]
  for r in v:validate_command(r)
  prog.append(v+[0]*14)
 expected_load=[];expected_store=[]
 for v in prog:
  for r in v:
   c=decode(r)
   if c["opcode"] in ("DMA_LOAD","DMA_STORE"):
    f=c["fields"];(expected_load if c["opcode"]=="DMA_LOAD" else expected_store).append((f["ddr_address"],f["byte_count"],c["banks"][0]))
 declarations=[]
 for direction in ('inputs','outputs'):
  for name,width in binding[direction].items(): declarations.append(f'logic {"" if width==1 else f"[{width-1}:0] "}{name};')
 connections=',\n'.join(f'.{n}({n})' for d in ('inputs','outputs') for n in binding[d])
 init=[]
 for i,a in enumerate(assets):
  init.extend([f'asset_base[{i}]=32\'h{a["address"]:08x}; asset_size[{i}]={a["bytes"]}; asset_output[{i}]={int(a["kind"]=="expected")};',f'$readmemh("{dst/a["name"]}.bytehex",asset_bytes[{i}],0,{a["bytes"]-1});'])
 for direction,commands in (("load",expected_load),("store",expected_store)):
  for i,(address,length,tag) in enumerate(commands):init.append(f'expected_{direction}_address[{i}]=32\'h{address:08x}; expected_{direction}_length[{i}]={length}; expected_{direction}_tag[{i}]={tag};')
 for stage,v in enumerate(prog):
  for k,r in enumerate(v):init.append(f'programs[{stage}][{k}]=128\'h{r:032x};')
 template=(HERE/'tb_template.sv').read_text()
 for k,val in {'DECLARATIONS':'\n'.join(declarations),'CONNECTIONS':connections,'ASSETS':str(len(assets)),'MAX_BYTES':str(max(a['bytes'] for a in assets)),'LOAD_COMMANDS':str(len(expected_load)),'STORE_COMMANDS':str(len(expected_store)),'STAGES':str(len(prog)),'INITIALIZE':'\n'.join(init),'SUITE':suite}.items():template=template.replace('@'+k+'@',val)
 (dst/'audit_fabric_tb.sv').write_text(template)
 (dst/'suite.json').write_text(json.dumps({'suite':suite,'assets':assets,'stages':len(prog),'generated_extra_quant_store':suite=='pingpong_quant_gemm','status':'PREPARED_NOT_EXECUTED'},indent=2)+'\n')
(HERE/'fixture_pins.json').write_text(json.dumps(pins,indent=2)+'\n')
print('PREPARED_INDEPENDENT_NUMERICAL_TB_NO_RUNTIME_CLAIM')
