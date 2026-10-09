"""Actual ISA tile-crossing/max-context fixtures, explicitly scoped state seeds."""
import argparse,hashlib,json,time
from pathlib import Path
import torch
from transformers import DynamicCache
from safetensors.torch import save_file
from prepare import prepare,quantized_reference
from compiler import Compiler
from interpreter import Interpreter
from validate import metrics
BASE=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--max-prefill',action='store_true');args=parser.parse_args()
    out=BASE/'evidence/isa_extended_run001'
    out.mkdir(exist_ok=False)
    torch.set_num_threads(4);torch.set_num_interop_threads(1)
    ddr,memory,quant=prepare();model=quantized_reference(quant);compiler=Compiler(memory)
    cases=[('prefill17',[9707,11]*8+[9707],0,'prefill')]
    if args.max_prefill:cases.append(('prefill512',[9707,11]*256,0,'prefill'))
    cases.append(('decode1024',[151643],1023,'decode'))
    results=[]
    for name,tokens,prefix,phase in cases:
        print('CASE '+name,flush=True);cache=DynamicCache()
        if prefix:
            seed=([9707,11]*512)[:prefix]
            with torch.inference_mode():
                model(torch.tensor([seed[:512]]),past_key_values=cache,use_cache=True,num_logits_to_keep=1)
                model(torch.tensor([seed[512:]]),past_key_values=cache,use_cache=True,num_logits_to_keep=1)
            for layer in range(24):
                for kind,index in [('K',0),('V',1)]:
                    for h in range(2):ddr.write(memory['KV'][f'{layer}.{kind}.{h}'],cache[layer][index][0,h].contiguous().view(torch.uint8).flatten())
        with torch.inference_mode():ref=model(torch.tensor([tokens]),past_key_values=cache,use_cache=True,num_logits_to_keep=1)
        sim=Interpreter(ddr);digest=hashlib.sha256();begin=time.monotonic()
        for ci,chunk in enumerate(compiler.chunks(tokens,prefix,phase)):
            for c in chunk:digest.update(c.encode())
            sim.run_chunk(chunk)
            if ci%25==0:print(f'{name}: chunks={ci+1} commands={sim.executed} seconds={time.monotonic()-begin:.1f}',flush=True)
        length=prefix+len(tokens)
        got=ddr.read(memory['logits'],151936*2).view(torch.bfloat16).reshape(1,1,-1).clone()
        score=metrics(got,ref.logits);kv=[];saved={'logits':got,'reference_logits':ref.logits.contiguous()}
        for layer in range(24):
            for kind,index in [('K',0),('V',1)]:
                actual=torch.stack([ddr.read(memory['KV'][f'{layer}.{kind}.{h}'],length*128).view(torch.bfloat16).reshape(length,64) for h in range(2)])[None]
                kv.append({'layer':layer,'kind':kind,**metrics(actual,cache[layer][index])})
                # Only newly appended state is needed in the boundary fixture golden.
                saved[f'KV.{layer}.{kind}.new']=actual[:,:,prefix:,:].contiguous()
        passed=torch.isfinite(got).all().item() and score['relative_l2']<=.05 and score['cosine']>=.995 and max(x['relative_l2'] for x in kv)<=.05
        result={'case':name,'status':'passed' if passed else 'failed','prefix':prefix,'input_length':len(tokens),
                'cache_after':length,'instruction_count':sim.executed,'chunks':sim.chunks,'logits':score,'KV':kv,
                'program_sha256':digest.hexdigest(),'CPU_seconds':time.monotonic()-begin,
                'state_seed':'Offline quantized reference KV for prefix1023; no ISA claim for producing that prefix.' if prefix else 'Empty cache; all KV produced by ISA.'}
        save_file(saved,str(out/(name+'.safetensors')))
        (out/(name+'.json')).write_text(json.dumps(result,indent=2)+'\n');results.append(result)
        print(json.dumps({k:v for k,v in result.items() if k!='KV'},indent=2),flush=True)
    (out/'report.json').write_text(json.dumps({'status':'passed' if all(r['status']=='passed' for r in results) else 'failed','results':results,
      'source_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (BASE/'python').glob('*.py')},
      'limitations':['Offline sequential ISA tensor execution only. No RTL, board or original BF16 quality acceptance.','Boundary decode uses declared reference prefix seed, not an ISA1023-token generation chain.']},indent=2)+'\n')
if __name__=='__main__':main()
