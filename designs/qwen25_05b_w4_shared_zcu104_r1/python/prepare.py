"""Offline checkpoint quantization and DDR materialization, never PS runtime."""
import json
from pathlib import Path
import torch
from safetensors import safe_open
from safetensors.torch import load_file
import numeric as num
from interpreter import DDR

ROOT=Path(__file__).resolve().parents[3]
RESEARCH=ROOT/'verification/research/qwen2_5_0_5b_initial_review'
CHECKPOINT=Path('/tmp/llm2rtl-qwen-hf-cache/models--Qwen--Qwen2.5-0.5B/snapshots/060db6499f32faf8b98477b0a26969ef7d8b9987')

def prepare():
    ddr=DDR();memory={'weights':{},'parameters':{},'KV':{}};quant={}
    with safe_open(str(CHECKPOINT/'model.safetensors'),framework='pt',device='cpu') as f:
        for key in f.keys():
            w=f.get_tensor(key)
            if w.ndim==2:
                q,s=num.quantize(w);quant[key]=(q,s)
                n,k=q.shape
                tiled=q.reshape(n//128,128,k//128,128).permute(0,2,1,3).contiguous()
                codes=ddr.allocate(key+'.codes',num.pack(tiled))
                scales=ddr.allocate(key+'.scales',s.reshape(n//128,128,k//128).permute(0,2,1).contiguous())
                memory['weights'][key]={'n':n,'k':k,'codes':codes,'scales':scales}
                if key=='model.embed_tokens.weight':
                    memory['embedding_codes']=ddr.allocate('embedding.lookup.codes',num.pack(q))
                    padded=torch.zeros((n,8),dtype=torch.float32);padded[:,:7]=s
                    memory['embedding_scales']=ddr.allocate('embedding.lookup.scales',padded)
            else: memory['parameters'][key]=ddr.allocate(key,w)
    for key,d in memory['weights'].items():
        bias=key.removesuffix('weight')+'bias'
        if bias in memory['parameters']: d['bias']=memory['parameters'][bias]
    table=load_file(str(RESEARCH/'rope_table_candidate/table.safetensors'))
    assert len(table)==1
    memory['rope']=ddr.allocate('rope.cos_sin',next(iter(table.values())))
    for layer in range(24):
        for kind in ('K','V'):
            for head in range(2):
                memory['KV'][f'{layer}.{kind}.{head}']=ddr.allocate(f'KV.{layer}.{kind}.{head}',torch.zeros((1024,64),dtype=torch.bfloat16))
    memory['logits']=ddr.allocate('logits',torch.zeros(151936,dtype=torch.bfloat16))
    memory['DDR_bytes']=ddr.next-0x10000000
    return ddr,memory,quant

class ReferenceLinear(torch.nn.Module):
    """Independent full-output matmul per128 group; no K16 tree or ISA tiling."""
    def __init__(self,q,s,bias):
        super().__init__();self.q=q;self.s=s;self.bias=bias
    def forward(self,x):
        shape=x.shape[:-1];a=x.reshape(-1,x.shape[-1]).float()
        out=torch.zeros((a.shape[0],self.q.shape[0]),dtype=torch.float32)
        for g in range(self.s.shape[1]):
            group=a[:,g*128:(g+1)*128] @ self.q[:,g*128:(g+1)*128].float().T
            out=num.add(out,num.mul(group,self.s[:,g]))
        if self.bias is not None: out=num.add(out,self.bias.float())
        return num.bf16(out).reshape(*shape,self.q.shape[0])

def quantized_reference(quant):
    from transformers import AutoModelForCausalLM
    model=AutoModelForCausalLM.from_pretrained(str(CHECKPOINT),local_files_only=True,
                                            torch_dtype=torch.bfloat16,attn_implementation='eager').eval()
    for name,module in list(model.named_modules()):
        if isinstance(module,torch.nn.Linear):
            key='model.embed_tokens.weight' if name=='lm_head' else name+'.weight'
            parent,attr=name.rsplit('.',1) if '.' in name else ('',name)
            q,s=quant[key]
            setattr(model.get_submodule(parent),attr,ReferenceLinear(q,s,module.bias))
    q,s=quant['model.embed_tokens.weight']
    model.model.embed_tokens.weight.data.copy_(num.dequant(q,s))
    return model
