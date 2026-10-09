"""Pure control/address compiler. Imports no tensor or model execution library."""
from isa import *

class Compiler:
    def __init__(self,memory): self.mem=memory; self.serial=0
    def uid(self):
        self.serial=(self.serial%65535)+1
        return self.serial
    def load(self,bank,address,m,n,fmt,uid=None,layout=0,offset=0,btt=None,flags=BEGIN|FINAL):
        if btt is None:
            stride=int((n*{1:2,2:4,3:.5}[fmt]+15)//16)*16
            if layout==1: stride=1024*{1:2,2:4}[fmt]
            btt=m*stride
        return command('DMA_LOAD',a=bank,address=address,m=m if m<32 else 0,n=n,mode=fmt,
                       tensor=uid or self.uid(),layout=layout,offset=offset,btt=btt,flags=flags,
                       extent_n=m if m>=32 else 0)
    def extract(self,a,c,m,n,row=0,col=0,last=False):
        return command('VECTOR',a=a,c=c,m=m,n=n,row=row,col=col,mode=VEC['LAYOUT'],
                       flags=LAST_A if last else 0,tensor=self.uid())
    def cast(self,a,c,m,n):
        return command('VECTOR',a=a,c=c,m=m,n=n,mode=VEC['CAST'],flags=LAST_A,tensor=self.uid())
    def insert(self,a,c,m,n,total_n,col,uid,first=False,last=False):
        return command('VECTOR',a=a,c=c,m=m,n=n,col=col,extent_m=m,extent_n=total_n,
                       tensor=uid,mode=VEC['LAYOUT'],flags=INSERT|LAST_A|(BEGIN if first else 0)|(FINAL if last else 0))
    def weight(self,name,nt,kt):
        d=self.mem['weights'][name]; groups=d['k']//128
        yield self.load(7,d['codes']+(nt*groups+kt)*8192,128,128,3)
        yield self.load(8,d['scales']+(nt*groups+kt)*512,1,128,2)
    def linear_ps(self,src,name,m,nt,dst,uid,release=False):
        d=self.mem['weights'][name]; groups=d['k']//128
        for kt in range(groups):
            yield self.extract(src,6,m,128,col=kt*128,last=release and kt==groups-1)
            yield from self.weight(name,nt,kt)
            flags=(INIT if kt==0 else ACCUM)|LAST_A|LAST_B|LAST_SCALE|(FINAL if kt==groups-1 else 0)
            yield command('GEMM',a=6,b=7,c=dst,scale=8,m=m,n=128,k=128,
                          tensor=uid,group=kt,flags=flags)
    def projection(self,src,dst,name,m,bias=False,release=False):
        d=self.mem['weights'][name]; tiles=d['n']//128; output_uid=self.uid()
        for nt in range(tiles):
            yield from self.linear_ps(src,name,m,nt,11,self.uid(),release and nt==tiles-1)
            if bias:
                yield self.load(22,d['bias']+nt*256,1,128,1)
                yield command('VECTOR',a=11,b=22,c=19,m=m,n=128,mode=VEC['BIAS'],
                              flags=LAST_A|LAST_B,tensor=self.uid())
            else: yield self.cast(11,19,m,128)
            yield self.insert(19,dst,m,128,d['n'],nt*128,output_uid,nt==0,nt==tiles-1)
    def norm(self,src,dst,key,m,last=False):
        yield self.load(22,self.mem['parameters'][key],1,896,1)
        yield command('RMSNORM',a=src,b=22,c=dst,m=m,n=896,
                      flags=LAST_B|(LAST_A if last else 0),tensor=self.uid())
    def embeddings(self,tokens):
        m=len(tokens); q_uid=self.uid();s_uid=self.uid()
        for r,token in enumerate(tokens):
            flags=(BEGIN if r==0 else 0)|(FINAL if r==m-1 else 0)
            yield self.load(7,self.mem['embedding_codes']+token*448,m,896,3,q_uid,
                            offset=r*448,btt=448,flags=flags)
            yield self.load(8,self.mem['embedding_scales']+token*32,m,7,2,s_uid,
                            offset=r*32,btt=32,flags=flags)
        yield command('VECTOR',a=7,b=8,c=0,m=m,n=896,mode=VEC['DEQUANT'],
                      tensor=self.uid(),flags=LAST_A|LAST_B)
    def layer(self,layer,m,position):
        prefix=f'model.layers.{layer}.'
        yield from self.norm(0,1,prefix+'input_layernorm.weight',m)
        yield from self.projection(1,2,prefix+'self_attn.q_proj.weight',m,True)
        yield from self.projection(1,4,prefix+'self_attn.k_proj.weight',m,True)
        yield from self.projection(1,5,prefix+'self_attn.v_proj.weight',m,True,True)
        yield self.load(22,self.mem['rope']+position*256,m,128,1)
        yield command('ROPE',a=2,b=22,c=3,m=m,n=14,k=64,tensor=self.uid(),flags=LAST_A)
        yield command('ROPE',a=4,b=22,c=6,m=m,n=2,k=64,tensor=self.uid(),flags=LAST_A|LAST_B)
        yield self.extract(6,4,m,128,last=True)
        # Explicit per-token/head contiguous stores. No hidden strided DMA.
        for bank,kind in ((4,'K'),(5,'V')):
            for head in range(2):
                for r in range(m):
                    base=self.mem['KV'][f'{layer}.{kind}.{head}']
                    yield command('DMA_STORE',a=bank,address=base+(position+r)*128,
                                  offset=r*256+head*128,btt=128,mode=1,m=m,n=128,
                                  flags=LAST_A if head==1 and r==m-1 else 0)
        length=position+m; out_uid=self.uid()
        for head in range(2):
            yield self.load(9,self.mem['KV'][f'{layer}.K.{head}'],length,64,1)
            yield self.load(10,self.mem['KV'][f'{layer}.V.{head}'],length,64,1)
            for local in range(7):
                qhead=head*7+local
                yield self.extract(3,6,m,64,col=qhead*64,last=qhead==13)
                yield command('GEMM',a=6,b=9,c=18,m=m,n=length,k=64,mode=1,
                              flags=INIT|FINAL|LAST_A|(LAST_B if local==6 else 0),layout=1,tensor=self.uid())
                yield command('SOFTMAX_MASKED',a=18,c=21,m=m,n=length,position=position,
                              flags=LAST_A,layout=1,tensor=self.uid())
                yield command('GEMM',a=21,b=10,c=11,m=m,n=64,k=length,mode=2,
                              flags=INIT|FINAL|LAST_A|(LAST_B if local==6 else 0),tensor=self.uid())
                yield self.cast(11,19,m,64)
                yield self.insert(19,2,m,64,896,qhead*64,out_uid,qhead==0,qhead==13)
        yield from self.projection(2,1,prefix+'self_attn.o_proj.weight',m,release=True)
        yield command('VECTOR',a=0,b=1,c=3,m=m,n=896,mode=VEC['ADD'],
                      flags=LAST_A|LAST_B,tensor=self.uid())
        yield from self.norm(3,1,prefix+'post_attention_layernorm.weight',m)
        psuids=[self.uid() for _ in range(7)]
        for kt in range(38):
            for name,dst in (('gate_proj',19),('up_proj',20)):
                yield from self.linear_ps(1,prefix+'mlp.'+name+'.weight',m,kt,18,self.uid(),
                                          release=kt==37 and name=='up_proj')
                yield self.cast(18,dst,m,128)
            yield command('VECTOR',a=19,b=20,c=6,m=m,n=128,mode=VEC['SILU_MUL'],
                          flags=LAST_A|LAST_B,tensor=self.uid())
            for nt in range(7):
                yield from self.weight(prefix+'mlp.down_proj.weight',nt,kt)
                yield command('GEMM',a=6,b=7,c=11+nt,scale=8,m=m,n=128,k=128,group=kt,
                              flags=(INIT if kt==0 else ACCUM)|LAST_B|LAST_SCALE|
                                    (LAST_A if nt==6 else 0)|(FINAL if kt==37 else 0),tensor=psuids[nt])
        out_uid=self.uid()
        for nt in range(7):
            yield self.cast(11+nt,19,m,128)
            yield self.insert(19,1,m,128,896,nt*128,out_uid,nt==0,nt==6)
        yield command('VECTOR',a=3,b=1,c=0,m=m,n=896,mode=VEC['ADD'],
                      flags=LAST_A|LAST_B,tensor=self.uid())
    def logits(self,m):
        yield self.extract(0,2,1,896,row=m-1,last=True)
        yield from self.norm(2,1,'model.norm.weight',1,last=True)
        for nt in range(1187):
            yield from self.linear_ps(1,'model.embed_tokens.weight',1,nt,11,self.uid(),release=nt==1186)
            yield self.cast(11,19,1,128)
            yield command('DMA_STORE',a=19,address=self.mem['logits']+nt*256,btt=256,
                          mode=1,m=1,n=128,flags=LAST_A)
    def program(self,tokens,prefix=0,phase='prefill'):
        if phase not in ('prefill','decode'): raise ValueError('phase')
        if not tokens or (phase=='decode' and len(tokens)!=1) or (phase=='prefill' and len(tokens)>512):
            raise ValueError('input scope')
        if prefix<0 or prefix+len(tokens)>1024 or any(not 0<=t<151936 for t in tokens):
            raise ValueError('context/token scope')
        if phase=='prefill' and prefix!=0: raise ValueError('prefill requires empty cache')
        for start in range(0,len(tokens),16):
            tile=tokens[start:start+16];m=len(tile)
            yield from self.embeddings(tile)
            for layer in range(24): yield from self.layer(layer,m,prefix+start)
            if start+m==len(tokens): yield from self.logits(m)
    def chunks(self,tokens,prefix=0,phase='prefill'):
        chunker=Chunker()
        for c in self.program(tokens,prefix,phase): yield from chunker.push(c)
        yield from chunker.flush()
