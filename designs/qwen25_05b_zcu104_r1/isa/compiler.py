"""Address/shape-only compiler for batch-one bounded Qwen prefill and decode.

No model tensor arithmetic is permitted in command generation. DDR allocations
and immutable checkpoint/table provisioning precede program execution.
"""
import torch
from interpreter import Command

class Compiler:
    def __init__(self,ddr,weights,cos,sin,context=2048,output_tile=128,group_size=128):
        if not 1<=context<=2048 or not 1<=output_tile<=128:raise ValueError('unsupported context/tile')
        self.cached_length=0;self.cache_fault=False;self.pending=False;self.scratch_seq=0
        self.ddr=ddr;self.weights=weights;self.cos=cos;self.sin=sin
        if group_size not in (32,128):raise ValueError('unsupported group size')
        self.group=group_size;self.context=context;self.tile=output_tile;self.commands=[];self.records={};self.tag=0
        self.cache=[(self.empty(f'cache{k}.K',(context,128)),
                     self.empty(f'cache{k}.V',(context,128))) for k in range(24)]
    def empty(self,name,shape,fmt='BF16'):
        dtype=torch.bfloat16 if fmt=='BF16' else torch.float32
        name=f'{name}.scratch{self.scratch_seq}';self.scratch_seq+=1
        capacity=max(4,shape[0])*shape[1]*torch.empty((),dtype=dtype).element_size()
        return self.ddr.allocate(name,torch.zeros(shape,dtype=dtype),capacity_nbytes=capacity)
    def emit(self,op,banks=(),params=(),address=0,dma=()):
        self.commands.append(Command(op,tuple(banks),tuple(params),address,tuple(dma),self.tag))
        self.tag=(self.tag+1)%65536
    def load(self,address,bank,rows,columns,stride=None,bytes_per_element=2):
        self.emit('DMA_LOAD',(bank,),address=address,
                  dma=(rows,columns*bytes_per_element,(stride or columns)*bytes_per_element,0))
    def store(self,address,bank,rows,columns,stride=None,bytes_per_element=2):
        self.emit('DMA_STORE',(bank,),address=address,
                  dma=(rows,columns*bytes_per_element,(stride or columns)*bytes_per_element,0))
    def projection(self,input_address,m,k,n,key,output_fp32=False):
        output=self.empty(key+'.out',(m,n),'FP32' if output_fp32 else 'BF16')
        q,s,bias=self.weights[key]
        self.load(input_address,0,m,k)
        for start in range(0,n,self.tile):
            width=min(self.tile,n-start)
            self.load(q+start*((k+1)//2),1,width,(k+1)//2,bytes_per_element=1)
            groups=(k+self.group-1)//self.group
            self.load(s+start*groups*2,2,width,groups)
            self.load(bias+start*2,3,1,width)
            self.emit('GEMM_W4',(0,1,2,3,4),(m,width,k,self.group))
            if output_fp32:
                self.emit('CAST',(4,5),(m,width));bank=5
            else:bank=4
            element_bytes=4 if output_fp32 else 2
            self.store(output+start*element_bytes,bank,m,width,n,element_bytes)
        return output
    def norm(self,address,m,key):
        output=self.empty(key+'.out',(m,896))
        self.load(address,0,m,896);self.load(self.weights[key],3,1,896)
        self.emit('RMSNORM',(0,3,4),(m,896));self.store(output,4,m,896)
        return output
    def rope(self,address,m,heads,start):
        output=self.empty('rope.out',(m,heads*64))
        self.load(address,0,m,heads*64)
        self.load(self.cos+start*64*2,10,m,64);self.load(self.sin+start*64*2,11,m,64)
        self.emit('ROPE',(0,10,11,4),(m,heads,64));self.store(output,4,m,heads*64)
        return output
    def vector(self,op,a,b,m,k):
        output=self.empty(op+'.out',(m,k))
        self.load(a,0,m,k);self.load(b,5,m,k)
        self.emit(op,(0,5,4),(m,k));self.store(output,4,m,k)
        return output
    def program(self,tokens,start=0):
        if self.cache_fault or self.pending or start!=self.cached_length:
            raise ValueError('cache prefix not committed or noncontiguous append')
        if not tokens or len(tokens)>4 or start<0 or start+len(tokens)>self.context:
            raise ValueError('workload outside current token tile/context')
        if any(not isinstance(t,int) or t<0 or t>=151936 for t in tokens):
            raise ValueError('token outside vocabulary')
        self.commands=[];self.scratch_seq=0;m=len(tokens);length=start+m
        hidden=self.empty('embedding.out',(m,896));q,s,_=self.weights['model.embed_tokens.weight']
        for row,token in enumerate(tokens):
            self.load(q+token*448,1,1,448,bytes_per_element=1)
            groups=896//self.group
            self.load(s+token*groups*2,2,1,groups)
            self.emit('DEQUANT',(1,2,0),(1,1,896,self.group));self.store(hidden+row*896*2,0,1,896)
        layers=[]
        for layer in range(24):
            prefix=f'model.layers.{layer}.'
            residual=hidden;normal=self.norm(hidden,m,prefix+'input_layernorm.weight')
            qproj=self.projection(normal,m,896,896,prefix+'self_attn.q_proj.weight')
            kproj=self.projection(normal,m,896,128,prefix+'self_attn.k_proj.weight')
            vproj=self.projection(normal,m,896,128,prefix+'self_attn.v_proj.weight')
            qrot=self.rope(qproj,m,14,start);krot=self.rope(kproj,m,2,start)
            cachek,cachev=self.cache[layer]
            self.load(krot,0,m,128);self.store(cachek+start*128*2,0,m,128)
            self.load(vproj,0,m,128);self.store(cachev+start*128*2,0,m,128)
            self.load(qrot,6,m,896);self.load(cachek,8,length,128);self.load(cachev,9,length,128)
            self.emit('ATTENTION',(6,8,9,4),(m,length,start,64))
            context=self.empty('attention.out',(m,896));self.store(context,4,m,896)
            attention_output=self.projection(context,m,896,896,prefix+'self_attn.o_proj.weight')
            hidden=self.vector('ADD',residual,attention_output,m,896)
            residual=hidden;normal=self.norm(hidden,m,prefix+'post_attention_layernorm.weight')
            gate=self.projection(normal,m,896,4864,prefix+'mlp.gate_proj.weight')
            up=self.projection(normal,m,896,4864,prefix+'mlp.up_proj.weight')
            activated=self.vector('SILU_MUL',gate,up,m,4864)
            down=self.projection(activated,m,4864,896,prefix+'mlp.down_proj.weight')
            hidden=self.vector('ADD',residual,down,m,896);layers.append(hidden)
        normal=self.norm(hidden,m,'model.norm.weight')
        logits=self.projection(normal,m,896,151936,'model.embed_tokens.weight',output_fp32=True)
        self.emit('END')
        self.records={'layers':layers,'logits':logits,'tokens':tokens,'cache_length':length}
        if len(self.commands)>24576:
            raise ValueError('complete program exceeds command memory capacity')
        self.pending=True
        return list(self.commands),dict(self.records)

    def execute(self,interpreter,tokens,start=0):
        commands,records=self.program(tokens,start)
        try:
            interpreter.run(commands)
        except Exception:
            self.cache_fault=True;self.pending=False
            raise
        self.cached_length=start+len(tokens);self.pending=False
        return commands,records

    def reset_cache(self):
        self.cached_length=0;self.cache_fault=False;self.pending=False
