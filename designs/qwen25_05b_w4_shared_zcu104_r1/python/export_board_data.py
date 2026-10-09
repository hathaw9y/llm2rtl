"""Offline checkpoint export and ISA golden; no deployed PS tensor execution."""
import argparse,json,hashlib,time
from pathlib import Path
import torch
from prepare import prepare,CHECKPOINT,RESEARCH
from compiler import Compiler
from interpreter import Interpreter
BASE=Path(__file__).resolve().parents[1]
def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('out',type=Path);a=p.parse_args();a.out.mkdir(exist_ok=False,parents=True);torch.set_num_threads(2);began=time.monotonic();ddr,memory,quant=prepare();del quant
 base=0x10000000;image=a.out/'model_ddr.bin'
 with image.open('wb') as f:
  cursor=base
  for address,name,raw in ddr.regions:
   f.write(bytes(address-cursor));f.write(raw.numpy().tobytes());cursor=address+raw.numel()
 assert image.stat().st_size==memory['DDR_bytes']
 (a.out/'DDR_layout.json').write_text(json.dumps(memory,indent=2)+'\n')
 sim=Interpreter(ddr);compiler=Compiler(memory);results=[]
 for phase,tokens,prefix in [('prefill',[9707,11],0),('decode',[151643],2)]:
  commands=0;chunks=0
  for chunk in compiler.chunks(tokens,prefix,phase):sim.run_chunk(chunk);commands+=len(chunk)-1;chunks+=1
  logits=ddr.named['logits'][1];path=a.out/(phase+'_logits.bin');path.write_bytes(logits.numpy().tobytes());kv=bytearray()
  for layer in range(24):
   for kind in ('K','V'):
    for head in range(2):kv.extend(ddr.named[f'KV.{layer}.{kind}.{head}'][1][:128*(prefix+len(tokens))].numpy().tobytes())
  cache=a.out/(phase+'_KV_valid_prefix.bin');cache.write_bytes(kv)
  results.append({'phase':phase,'tokens':tokens,'prefix':prefix,'commands':commands,'chunks':chunks,'logits_sha256':sha(path),'KV_valid_prefix_sha256':sha(cache),'cache_after':prefix+len(tokens)})
  print(results[-1],flush=True)
 manifest={'status':'offline_image_and_ISA_goldens','checkpoint_revision':CHECKPOINT.name,'checkpoint_sha256':sha(CHECKPOINT/'model.safetensors'),'model_source_sha256':sha(RESEARCH/'modeling_qwen2.py'),'DDR_base':base,'DDR_end_exclusive':base+memory['DDR_bytes'],'DDR_bytes':memory['DDR_bytes'],'DDR_image_sha256':sha(image),'source_sha256':{str(p.relative_to(BASE)):sha(p) for p in sorted((BASE/'python').glob('*.py'))},'workloads':results,'KV_dump_order':'layer0..23, K then V, head0 then head1, prefix rows contiguous128B. Dump onlyvalid prefix; remaining1024 capacity is unspecified.','limits':['Offline ISA numerical golden only; no full-model RTL or physical board claim.','Original BF16 W4 quality probe and extended prefill512 KV tolerance remain failed; see evidence reports.'],'seconds':time.monotonic()-began}
 (a.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
if __name__=='__main__':main()
