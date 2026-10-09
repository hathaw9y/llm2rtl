#!/usr/bin/env python3
import pathlib,sys,json,struct,hashlib
H=pathlib.Path(__file__).resolve().parent;D=H.parents[1];sys.path.insert(0,str(D/'scripts'));from isa_codec import encode
O=H/'fabric_negative_vectors';O.mkdir(exist_ok=True)
sha=lambda b:hashlib.sha256(b).hexdigest()
source=struct.pack('<576H',*[0x3f00+(k*37)%256 for k in range(576)]);(O/'source.bin').write_bytes(source);(O/'source.hex').write_text(''.join(f'{int.from_bytes(source[j:j+16],"little"):032x}\n' for j in range(0,len(source),16)))
(O/'expected_store.bin').write_bytes(source[:128]);(O/'expected_store.hex').write_text(''.join(f'{int.from_bytes(source[j:j+16],"little"):032x}\n' for j in range(0,128,16)))
cfg=encode('BANK_CONFIG',(2,0,0),profile=3,rows=1,cols=576,generation=1)
def load(offset,n):return encode('DMA_LOAD',(2,0,0),ddr_address=0x100000+offset,byte_count=n,local_byte_offset=offset)
store=encode('DMA_STORE',(2,0,0),ddr_address=0x200000,byte_count=128,local_byte_offset=0)
programs={'partial_duplicate':[cfg,load(0,1136),load(0,16),store,0],'fill_tail_next_start':[load(1136,16),store,0],'fault_load':[cfg,load(0,1152),0],'full_load':[cfg,load(0,1152),0],'fault_store_next_start':[store,0]}
for n,rs in programs.items():(O/(n+'.hex')).write_text(''.join(f'{r:032x}\n' for r in rs))
m={'scope':'Prepared independent control/payload negative fixtures; actual fabric RTL required, no DUT preload/model substitutes','source_bytes':1152,'source_address':0x100000,'expected_store_address':0x200000,'expected_store_bytes':128,'programs':{n:{'records':len(v),'sha256':sha((O/(n+'.hex')).read_bytes())} for n,v in programs.items()},'assets':{n:sha((O/n).read_bytes()) for n in ['source.bin','source.hex','expected_store.bin','expected_store.hex']},'codec_sha256':sha((D/'scripts/isa_codec.py').read_bytes()),'checks':['partial1136of1152plusduplicate16 cannotmake whole source ready; STORE128 rejects04 with no native/vendor S2MM','subsequent START fills only missing16 without config and preserves physicaldata+coverage; exact128byte STORE succeeds','first partialKEEPffffe malformed LOAD beat never writes, firstfault60 sticky and busy ownership retained; coordinated reset only recovery','vendor cmd offered before earlybadstatus stays stable through stall/error and eventually can accept','STORE held AXIS beat stable after wrongtag, native pending responses drain, source retained and no syntheticcompletion','all memory/compute/control instances real; DDRonly external BFM']}
(O/'manifest.json').write_text(json.dumps(m,indent=2)+'\n');print(json.dumps(m))
