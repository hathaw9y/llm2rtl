"""Fresh full-model small-path ISA evidence; maximum cases remain separate."""
import argparse,hashlib,json,time
from dataclasses import asdict
from pathlib import Path
import torch
from safetensors.torch import save_file,load_file
from transformers import DynamicCache
from prepare import prepare,quantized_reference,RESEARCH,CHECKPOINT
from compiler import Compiler
from interpreter import Interpreter
from isa import *

BASE=Path(__file__).resolve().parents[1]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def metrics(actual,expected):
    a=actual.float().flatten();b=expected.float().flatten();delta=a-b
    norm=torch.linalg.vector_norm(b)
    return {'max_abs':delta.abs().max().item(),
            'relative_l2':(torch.linalg.vector_norm(delta)/norm.clamp_min(1e-30)).item(),
            'cosine':torch.nn.functional.cosine_similarity(a,b,dim=0).item(),
            'BF16_bit_mismatches':int((actual.view(torch.int16)!=expected.view(torch.int16)).sum())}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--run',default='isa_small_run002')
    args=parser.parse_args()
    torch.set_num_threads(4);torch.set_num_interop_threads(1)
    out=BASE/'evidence'/args.run
    if out.exists(): raise RuntimeError('Evidence directory already exists; choose a new run.')
    out.mkdir()
    started=time.monotonic();print('Preparing exact checkpoint W4 DDR images...',flush=True)
    ddr,memory,quant=prepare()
    (out/'DDR_layout.json').write_text(json.dumps(memory,indent=2)+'\n')
    print(f'DDR image {memory["DDR_bytes"]} bytes; preparation {time.monotonic()-started:.1f}s',flush=True)
    model=quantized_reference(quant);cache=DynamicCache()
    sim=Interpreter(ddr);compiler=Compiler(memory);results=[];golden={};vectors={}
    for phase,tokens,prefix in [('prefill',[9707,11],0),('decode',[151643],2)]:
        with torch.inference_mode():
            ref=model(torch.tensor([tokens]),past_key_values=cache,use_cache=True,num_logits_to_keep=1)
        count_start=sim.executed;chunk_start=sim.chunks;begin=time.monotonic()
        digest=hashlib.sha256()
        program_path=out/(phase+'.bin')
        with program_path.open('wb') as program:
            for ci,chunk in enumerate(compiler.chunks(tokens,prefix,phase)):
                if chunk[-1].opcode!=0: raise ValueError('missing END')
                for pc,c in enumerate(chunk):
                    raw=c.encode();program.write(raw);digest.update(raw)
                    if c.opcode==0: continue
                    signature=(c.opcode,c.mode,bool(c.flags&INIT),bool(c.flags&ACCUM),bool(c.flags&INSERT))
                    if signature not in golden:
                        key='case'+str(len(golden))
                        before=sim.snapshot()
                        for bank in c.operand_banks():
                            if bank in sim.desc:
                                d=sim.desc[bank]
                                vectors[f'{key}.before.bank{bank}']=sim.raw[bank][:d.m*d.stride].clone()
                        sim.execute(c)
                        for bank in c.operand_banks():
                            if bank in sim.desc:
                                d=sim.desc[bank]
                                vectors[f'{key}.after.bank{bank}']=sim.raw[bank][:d.m*d.stride].clone()
                        golden[signature]={'case':key,'phase':phase,'chunk':ci,'pc':pc,
                                           'command':asdict(c),'record_hex':raw.hex(),
                                           'before':before,'after':sim.snapshot()}
                    else: sim.execute(c)
                sim.chunks+=1
                if ci%10==0: print(f'{phase}: chunk {ci}, commands {sim.executed-count_start}, elapsed {time.monotonic()-begin:.1f}s',flush=True)
        length=prefix+len(tokens)
        got=ddr.read(memory['logits'],151936*2).view(torch.bfloat16).reshape(1,1,-1).clone()
        original=load_file(str(RESEARCH/'original_reference_trace'/f'{phase}_tensors.safetensors'))
        # Original artifacts are identified by their own manifest and exact same token inputs.
        original_logits=next(v for k,v in original.items() if 'logits' in k)
        original_score=metrics(got,original_logits)
        quant_score=metrics(got,ref.logits)
        kv_results=[];saved={'logits':got,'quantized_reference_logits':ref.logits.contiguous()}
        for layer in range(24):
            for kind,index in [('K',0),('V',1)]:
                actual=torch.stack([ddr.read(memory['KV'][f'{layer}.{kind}.{h}'],length*128).view(torch.bfloat16).reshape(length,64) for h in range(2)])[None].clone()
                target=cache[layer][index]
                kv_results.append({'layer':layer,'kind':kind,**metrics(actual,target)})
                saved[f'KV.{layer}.{kind}']=actual
        finite=bool(torch.isfinite(got).all()) and all(torch.isfinite(v).all() for v in saved.values())
        passed=finite and quant_score['relative_l2']<=.05 and quant_score['cosine']>=.995 and max(r['relative_l2'] for r in kv_results)<=.05
        quality=original_score['relative_l2']<=.35 and original_score['cosine']>=.90
        save_file(saved,str(out/(phase+'_tensors.safetensors')))
        result={'phase':phase,'tokens':tokens,'cache_before':prefix,'cache_after':length,
                'instruction_count':sim.executed-count_start,'chunk_count':sim.chunks-chunk_start,
                'program_sha256':digest.hexdigest(),'quantized_reference_logits':quant_score,
                'original_BF16_logits':original_score,'KV_comparisons':kv_results,
                'numeric_comparison_status':'passed' if passed else 'failed',
                'small_path_W4_quality_status':'passed' if quality else 'failed',
                'CPU_seconds':time.monotonic()-begin}
        results.append(result)
        print(json.dumps({k:v for k,v in result.items() if k!='KV_comparisons'},indent=2),flush=True)
    save_file(vectors,str(out/'command_golden.safetensors'))
    (out/'command_golden.json').write_text(json.dumps(list(golden.values()),indent=2)+'\n')
    report={'status':'passed_small_ISA_numeric_paths' if all(r['numeric_comparison_status']=='passed' for r in results) else 'failed_ISA_numeric',
            'original_BF16_quality_status':'passed_small_probe' if all(r['small_path_W4_quality_status']=='passed' for r in results) else 'failed_small_probe',
            'checkpoint_revision':'060db6499f32faf8b98477b0a26969ef7d8b9987',
            'checkpoint_sha256':sha(CHECKPOINT/'model.safetensors'),
            'source_sha256':sha(RESEARCH/'modeling_qwen2.py'),
            'python_source_identities':{str(p.relative_to(BASE)):sha(p) for p in sorted((BASE/'python').glob('*.py'))},
            'results':results,'opcode_counts':dict(sim.counts),'bank_peak_bytes':dict(sim.max_used),
            'golden_case_count':len(golden),'golden_sha256':sha(out/'command_golden.safetensors'),
            'limits':['Small original two-token prefill / one decode only. Maximum lengths and tile-crossing workloads not validated.',
                      'Sequential tensor interpreter; no cycle-level concurrency, RTL, synthesis or board evidence.',
                      'Quantized reference uses full-output FP32 matmul per128 group; ISA uses K16 tree and selected nonlinear approximations.',
                      'Original model quality numbers are a small-path probe, not a corpus-level quality claim.'],
            'CPU_total_seconds':time.monotonic()-started}
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    if report['status']!='passed_small_ISA_numeric_paths': raise RuntimeError('ISA numeric comparison failed; implementation gate stays closed.')

if __name__=='__main__': main()
