"""Execute packed-command round trips and compare with independent Transformers.

Candidate-only numerical ISA evidence. Quality loss vs original BF16 and
agreement with the same quantized reference are separate measurements.
"""
import argparse,hashlib,json,sys,time,types
import torch.nn.functional as F
from pathlib import Path
from collections import Counter
import torch
from transformers import AutoModelForCausalLM
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'quantization'))
from int4 import quantize_int4,dequantize_int4,pack_int4
from interpreter import DDR,Interpreter,BANK_BYTES
from compiler import Compiler

def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def metrics(actual,expected):
 a=actual.float();b=expected.float();delta=a-b
 return {'max_abs_error':float(delta.abs().max()),
  'rmse':float(delta.square().mean().sqrt()),
  'relative_rmse':float(delta.square().mean().sqrt()/b.square().mean().sqrt().clamp_min(1e-8))}
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--group-size',type=int,choices=[32,128],default=128)
 parser.add_argument('--run-id',default='run002')
 args=parser.parse_args();group=args.group_size
 source_manifest={str(p.relative_to(ROOT)):sha(p) for p in [Path(__file__),ROOT/'isa/interpreter.py',ROOT/'isa/compiler.py',ROOT/'quantization/int4.py',ROOT/'reference/modeling_qwen2.py']}
 torch.set_num_threads(8);torch.manual_seed(0)
 identity=json.loads((ROOT/'reference/reference_capture.json').read_text())['model_identity']
 checkpoint=Path('/home/shmin/.cache/huggingface/hub/models--Qwen--Qwen2.5-0.5B/snapshots')/identity['revision']
 model=AutoModelForCausalLM.from_pretrained(checkpoint,local_files_only=True,
       torch_dtype=torch.bfloat16,attn_implementation='eager').eval()
 ddr=DDR();weights={};starttime=time.monotonic()
 with torch.inference_mode():
  for key,param in model.named_parameters():
   if param.ndim==2:
    q,scale=quantize_int4(param,group);packed=pack_int4(q)
    base=key[:-len('weight')]
    bias=dict(model.named_parameters()).get(base+'bias',torch.zeros(param.shape[0],dtype=torch.bfloat16))
    weights[key]=(ddr.allocate(key+'.q',packed),ddr.allocate(key+'.scale',scale),ddr.allocate(key+'.bias',bias))
    param.copy_(dequantize_int4(q,scale,group))
   elif key.endswith('weight'):weights[key]=ddr.allocate(key,param)
 # Offline immutable RoPE table matches the pinned library, not PS runtime math.
 rope=model.model.layers[0].self_attn.rotary_emb
 cos=ddr.allocate('rope.cos',rope.cos_cached[:2048].to(torch.bfloat16))
 sin=ddr.allocate('rope.sin',rope.sin_cached[:2048].to(torch.bfloat16))
 compiler=Compiler(ddr,weights,cos,sin,group_size=group);vm=Interpreter(ddr)
 outdir=ROOT/'isa'/f'group{group}'/args.run_id;outdir.mkdir(parents=True,exist_ok=False)
 # Independent model keeps its original layer/norm/attention logic; projection
 # forward explicitly implements the proposed FP32 accumulation/bias boundary.
 # Native BF16 linear is not assumed bit-identical to this arithmetic policy.
 def fp32_projection(module,inputs):
  bias=module.bias.float() if module.bias is not None else None
  return F.linear(inputs.float(),module.weight.float(),bias).to(inputs.dtype)
 for module in model.modules():
  if isinstance(module,torch.nn.Linear):module.forward=types.MethodType(fp32_projection,module)
 snapshots=[];handles=[]
 for layer in model.model.layers:
  handles.append(layer.register_forward_hook(lambda mod,inp,out:snapshots.append(out[0].detach().clone())))
 results=[];past=None
 # Fixed numerical acceptance for same-format software equivalence, declared
 # before comparison; does not qualify model quality or hardware arithmetic.
 tolerance={'layer_and_logits_relative_rmse_max':0.03,'logits_max_abs_error_max':1.0}
 for workload,tokens,start in [('prefill',[1,2,3,4],0),('decode',[5],4)]:
  snapshots.clear()
  with torch.inference_mode():
   reference=model(input_ids=torch.tensor([tokens]),past_key_values=past,use_cache=True)
  past=reference.past_key_values
  before=Counter(vm.counts)
  commands,records=compiler.execute(vm,tokens,start)
  encoded=b''.join(c.encode() for c in commands)
  program_path=outdir/f'{workload}.bin';program_path.write_bytes(encoded)
  actual=ddr.tensor(records['logits'],(1,len(tokens),151936),'FP32')
  layers=[metrics(ddr.tensor(addr,(1,len(tokens),896)),snapshots[i]) for i,addr in enumerate(records['layers'])]
  logits_metrics=metrics(actual,reference.logits)
  cache_metrics=[]
  for layer,(kaddr,vaddr) in enumerate(compiler.cache):
   for name,addr,index in [('K',kaddr,0),('V',vaddr,1)]:
    cached=ddr.tensor(addr,(start+len(tokens),128)).view(start+len(tokens),2,64).transpose(0,1).unsqueeze(0)
    cache_metrics.append({'layer':layer,'kind':name,**metrics(cached,past[layer][index])})
  original=torch.load(ROOT/'reference'/f'{workload}.pt',weights_only=True)['logits']
  agree=all(x['relative_rmse']<=tolerance['layer_and_logits_relative_rmse_max'] for x in layers+[logits_metrics]+cache_metrics)
  agree=agree and logits_metrics['max_abs_error']<=tolerance['logits_max_abs_error_max']
  vector_path=outdir/f'{workload}_logits.pt';torch.save(actual,vector_path)
  results.append({'workload_id':workload,'status':'passed' if agree else 'failed',
    'vector_sha256':sha(vector_path),'program_sha256':sha(program_path),
    'command_count':len(commands),'program_bytes':len(encoded),
    'opcode_counts':dict(vm.counts-before),'layer_metrics':layers,'logits_metrics':logits_metrics,
    'cache_metrics':cache_metrics,'quantization_drift_vs_original_bf16':metrics(actual,original),
    'argmax_agreement_with_quantized_reference':float((actual.argmax(-1)==reference.logits.argmax(-1)).float().mean())})
  print(json.dumps({'workload':workload,'status':results[-1]['status'],'logits':logits_metrics,
                    'commands':len(commands)},indent=2),flush=True)
 for handle in handles:handle.remove()
 report={'status':'passed' if all(x['status']=='passed' for x in results) else 'failed',
  'design_id':'qwen25_05b_zcu104','revision':'r1','group_size':group,
  'reference':'Independent pinned Transformers eager model with candidate INT4 dequantized BF16 weights and explicit FP32 linear accumulation/bias before BF16 cast; original BF16 capture separately compared',
  'model_identity':identity,'tolerance':tolerance,'workload_results':results,
  'bank_highwater_bytes':dict(vm.max_bytes),'declared_bank_capacity_bytes':BANK_BYTES,
  'allocated_ddr_bytes':sum(x[2].numel() for x in ddr.regions),'ddr_regions':len(ddr.regions),
  'command_memory_capacity_proposal_records':24576,
  'packed_transport':'Every executed command encoded and decoded from a canonical 64-byte record',
  'no_host_tensor_compute':True,
  'source_manifest':source_manifest,
  'elapsed_seconds':time.monotonic()-starttime,
  'limitations':['Numerical reference uses PyTorch FP32 reductions; no RTL bit-exact accumulation order proven.',
   'Sequential software execution does not model scoreboard concurrency or ready/valid responses.',
   'Only synthetic tokens [1,2,3,4] then cached [5] executed; context2048 is a proposed capacity, not validated full workload.',
   'Synthetic DDR addresses are not approved board linker ranges.',
   'Quantization quality is assessed separately; same-format agreement is not quality approval.',
   'Command memory and physical bank fit require synthesis; no RTL, Vivado, or hardware result.']}
 (outdir/'validation_report.json').write_text(json.dumps(report,indent=2)+'\n')
 return 0 if report['status']=='passed' else 1
if __name__=='__main__':raise SystemExit(main())
