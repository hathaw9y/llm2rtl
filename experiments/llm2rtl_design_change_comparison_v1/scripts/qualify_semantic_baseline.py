#!/usr/bin/env python3
"""Reference/semantic ISA qualification. This does NOT emulate RTL arithmetic."""
from pathlib import Path
import argparse,sys,json,time,hashlib,datetime,platform
from collections import Counter
p=argparse.ArgumentParser();p.add_argument('--snapshot',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--cases',type=int,default=16);a=p.parse_args()
a.out.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(a.snapshot/'verification/prototypes'))
import torch,transformers
from transformers import AutoModelForCausalLM,AutoTokenizer
import smollm2_135m_isa_feasibility as isa
texts=[
 'The FPGA reads weights from memory and computes matrix products.',
 'A small language model predicts the next token in a sequence.',
 'Explain why water freezes when the temperature falls.',
 '한국어 문장으로 인공지능과 컴퓨터의 동작을 설명한다.',
 'Numbers in this list are 1, 2, 3, 5, 8, 13 and 21.',
 'The satellite sends telemetry to the ground station.',
 'Write a function that adds two integers and returns the result.',
 'An engineer checks the test results before changing the design.',
 'Trees grow slowly and depend on sunlight, soil and water.',
 'The patient story is fictional. A traveler describes a quiet village.',
 '오늘은 도서관에서 책을 읽고 내일은 공원에서 산책한다.',
 'A compiler translates a program into instructions for a machine.',
 'The sequence of hexadecimal bytes is AA 55 00 FF 12 34.',
 'Two friends plan a trip by train and compare the departure times.',
 'A telescope collects light from distant stars and galaxies.',
 'A recipe describes how to mix flour, water and salt.'
]
lengths=[1,7,16,31,32,33,63,64]*2
class FastMachine(isa.Machine):
 def run(self,program):
  for chunk in program.chunks:
   assert chunk and chunk[-1].op=='END' and len(chunk)<=1024
   for cmd in chunk:
    decoded=isa.wire_decode(isa.wire_record(cmd,self.ddr),self.ddr)
    assert decoded==cmd,(decoded,cmd)
    self.execute(decoded);self.check_oracle(decoded)
   self.chunks+=1
  return self.get(12) if self.valid[12] else None
 def snapshot(self,cmd):return {}
def repartition(program,limit=15):
 out=isa.Program();body=[cmd for chunk in program.chunks for cmd in chunk if cmd.op!='END']
 for i in range(0,len(body),limit):out.chunks.append(body[i:i+limit]+[isa.Cmd('END')])
 return out
def rawhash(t):return hashlib.sha256(t.contiguous().view(torch.uint16).numpy().tobytes()).hexdigest()
started=time.monotonic();torch.set_num_threads(4)
model=AutoModelForCausalLM.from_pretrained(str(isa.CHECKPOINT),local_files_only=True,dtype=torch.bfloat16,attn_implementation='eager').eval()
tokenizer=AutoTokenizer.from_pretrained(str(isa.CHECKPOINT),local_files_only=True)
captured={};handles=isa.install_reference_hooks(model,captured)
report={'status':'running','scope':'HF vs semantic torch-BF16 ISA interpreter only, including full channels and all 30 layer KV. Not RTL arithmetic, FPGA or hidden-input task qualification.','checkpoint':isa.CHECKPOINT.name,'torch':torch.__version__,'transformers':transformers.__version__,'python':platform.python_version(),'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'cases':[]}
try:
 with torch.inference_mode():
  for i in range(min(a.cases,16)):
   stream=tokenizer.encode((texts[i]+' ')*64,add_special_tokens=False)
   ids=stream[:lengths[i]];assert len(ids)==lengths[i]
   ddr=isa.DDR(model,ids);machine=FastMachine(ddr)
   # Chunk-equivalence copies for public length7 and public length33 cases.
   alt_ddr=isa.DDR(model,ids) if i in (1,5) else None
   alt=FastMachine(alt_ddr) if alt_ddr else None
   case={'id':f'case{i:02d}','split':'public' if i<8 else 'held_out_baseline_only','prefill_tokens':len(ids),'input_ids':ids,'steps':[]}
   cache=None;position=0;current=ids;old_kv={}
   # First step performs possibly multiple <=32-token prefill blocks.
   blocks=[ids[j:j+32] for j in range(0,len(ids),32)]
   for phase in range(len(blocks)+16):
    current=blocks[phase] if phase<len(blocks) else [int(reference.logits[0,-1].argmax())]
    count=len(current);captured.clear()
    reference=model(torch.tensor([current]),past_key_values=cache,use_cache=True,logits_to_keep=1)
    cache=reference.past_key_values
    machine.oracle={'captured':captured,'cache':cache,'start':position,'m':count}
    program=isa.build_block(current,position,final_logits=True)
    result=machine.run(program)
    assert torch.equal(result,reference.logits[0]),('logits',i,phase,isa.compare('logits',result,reference.logits[0]))
    for layer in range(30):
     for kind,attr in [('key','keys'),('value','values')]:
      actual=ddr.kv[layer,kind];expected=getattr(cache.layers[layer],attr)[0].transpose(0,1)
      assert torch.equal(actual,expected),('KV reference',i,phase,layer,kind)
      if (layer,kind) in old_kv:assert torch.equal(actual[:position],old_kv[layer,kind]),('KV prefix',i,phase,layer,kind)
    old_kv={key:value.clone() for key,value in ddr.kv.items()}
    if alt:
     alternative=alt.run(repartition(program))
     assert torch.equal(alternative,result),('chunk logits',i,phase)
     for key,value in ddr.kv.items():assert torch.equal(alt_ddr.kv[key],value),('chunk KV',i,phase,key)
     for bank in range(13):
      assert alt.valid[bank]==machine.valid[bank]
      if machine.valid[bank]:
       x,y=alt.bank[bank],machine.bank[bank]
       if isinstance(x,tuple):assert all(torch.equal(u,v) for u,v in zip(x,y))
       else:assert torch.equal(x,y),('chunk bank',i,phase,bank)
     assert alt.progress==machine.progress and alt.stores_since_fence==machine.stores_since_fence
    case['steps'].append({'phase':'prefill' if phase<len(blocks) else 'decode','position':position,'token_ids':current,'logits_exact':True,'all_30_layers_kv_exact':True,'kv_prefix_preserved':True,'alternate_chunk_exact':bool(alt),'logits_sha256':rawhash(result),'reference_internal_checks':dict(machine.oracle_checks)})
    position+=count
    print(f'CASE {i:02d} step={phase} position={position} logits/KV PASS',flush=True)
   case['status']='PASS';case['chunks']=machine.chunks;case['commands']=dict(machine.executed)
   report['cases'].append(case)
   report['elapsed_seconds']=time.monotonic()-started
   (a.out/'semantic_qualification.json').write_text(json.dumps(report,indent=2)+'\n')
 report['status']='PASS'
except Exception as exc:
 report['status']='FAIL';report['error']=repr(exc);raise
finally:
 report['elapsed_seconds']=time.monotonic()-started
 (a.out/'semantic_qualification.json').write_text(json.dumps(report,indent=2)+'\n')
 for handle in handles:handle.remove()
print('SEMANTIC_BASELINE_QUALIFICATION_PASS',flush=True)
