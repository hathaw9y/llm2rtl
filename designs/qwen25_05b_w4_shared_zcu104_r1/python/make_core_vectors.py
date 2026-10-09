"""Bounded integration packets from fresh actual ISA golden operands.
DMA transport is a declared testbench model, not DataMover/DDR board evidence.
"""
import json,hashlib
from pathlib import Path
from dataclasses import replace
import torch
from safetensors.torch import load_file
from isa import *
BASE=Path(__file__).resolve().parents[1]
def main():
 out=BASE/'evidence/core_packet_run002';out.mkdir(exist_ok=False)
 g=BASE/'evidence/isa_small_run002';records=json.loads((g/'command_golden.json').read_text());t=load_file(str(g/'command_golden.safetensors'));data=bytearray();gold=bytearray();headers=[];cases=[]
 def allocate(x,target):
  raw=bytes(x.contiguous().view(torch.uint8).flatten().tolist());assert len(raw)%16==0;address=(0x18000000 if target is gold else 0x10000000)+len(target);target.extend(raw);return address,len(raw)
 def inputs(r,skip=()):
  key=r['case'];result=[];c=Command(**r['command']);sources=[bank for bank,_ in c.sources()]
  for bank in sources:
   if bank in skip:continue
   d=r['before'][str(bank)];x=t[f'{key}.before.bank{bank}'];addr,btt=allocate(x,data)
   result.append(command('DMA_LOAD',a=bank,address=addr,btt=btt,m=d['m'] if d['m']<32 else 0,extent_n=d['m'] if d['m']>=32 else 0,n=d['n'],mode=d['fmt'],tensor=d['tensor'],layout=d['layout'],flags=BEGIN|FINAL))
  return result
 selected=[2,4,5,6,7,8,10,12,13,14,15,16,17]
 for index in selected:
  r=records[index];c=Command(**r['command']);packet=[]
  if index==7:
   first=records[6];packet+=inputs(first);packet.append(Command(**first['command']))
   packet.append(Command()) # retain group0 partial sum across END
   packet+=inputs(r);c=replace(c,flags=c.flags|FINAL)
  else:
   packet+=inputs(r)
   if c.opcode==3 and c.mode==0:c=replace(c,flags=c.flags|FINAL)
  packet.append(c)
  d=r['after'][str(c.c)];expected=t[f'{r["case"]}.after.bank{c.c}'];addr,btt=allocate(expected,gold)
  packet.append(command('DMA_STORE',a=c.c,address=addr,btt=btt,m=d['m'],n=d['n'],mode=d['fmt'],layout=d['layout']))
  packet.append(Command())
  chunks=[];current=[]
  for command_record in packet:
   current.append(command_record)
   if not command_record.opcode:chunks.append(current);current=[]
  for ci,chunk in enumerate(chunks):
   filename=f'{index}_{ci}.mem';(out/filename).write_text(''.join(f'{int.from_bytes(v.encode(),"little"):064x}\n' for v in chunk));headers.append(f'{filename} {len(chunk)}\n')
  cases.append({'original_case':r['case'],'commands':len(packet),'chunks':len(chunks),'modifications':'GEMM FINAL set for bounded packet store; case7 retains preceding group0 over END.' if c.opcode==3 and c.mode==0 else 'None','expected_bytes':btt})
 def write_words(name,raw):out.joinpath(name).write_text(''.join(f'{int.from_bytes(raw[i:i+16],"little"):032x}\n' for i in range(0,len(raw),16)))
 write_words('ddr_input.mem',data);write_words('ddr_expected.mem',gold);(out/'headers.txt').write_text(''.join(headers));(out/'sizes.txt').write_text(f'{len(data)//16} {len(gold)//16}\n')
 (out/'manifest.json').write_text(json.dumps({'cases':cases,'golden_sha256':hashlib.sha256((g/'command_golden.safetensors').read_bytes()).hexdigest(),'limitations':['Native DMA and bank latency models. No actual DataMover or physical DDR evidence.','Bounded command packets do not prove full-model RTL execution.']},indent=2)+'\n')
if __name__=='__main__':main()
