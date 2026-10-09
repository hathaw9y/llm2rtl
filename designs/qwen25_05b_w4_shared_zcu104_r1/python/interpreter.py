"""Sequential tensor ISA interpreter, not a cycle simulator or deployed PS code."""
from bisect import bisect_right
from collections import Counter
from dataclasses import dataclass, asdict
import torch
import numeric as num
from isa import *

DTYPE={1:torch.bfloat16,2:torch.float32,3:torch.uint8}

def stride_bytes(fmt,n,layout=0):
    if layout==LAYOUT_ATTENTION:
        if fmt not in (1,2): raise ValueError('attention format')
        n=1024
    size={1:2,2:4,3:.5}[fmt]
    return int((n*size+15)//16)*16

@dataclass
class Descriptor:
    fmt:int; m:int; n:int; stride:int; tensor:int; layout:int=0
    valid:bool=False; next_group:int=0; partial:bool=False

class DDR:
    """Offline synthetic32-bit address space; board linker reservation is separate."""
    def __init__(self): self.regions=[]; self.starts=[]; self.named={}; self.next=0x10000000
    def allocate(self,name,data):
        if name in self.named: raise ValueError('duplicate DDR allocation')
        raw=data.contiguous().view(torch.uint8).reshape(-1).clone()
        base=(self.next+127)//128*128
        self.regions.append((base,name,raw)); self.starts.append(base)
        self.named[name]=(base,raw); self.next=base+raw.numel()
        if self.next >= 1<<32: raise ValueError('DDR32 overflow')
        return base
    def resolve(self,address,nbytes):
        i=bisect_right(self.starts,address)-1
        if i<0 or nbytes<=0: raise ValueError('DDR range')
        base,name,raw=self.regions[i]
        if address+nbytes>base+raw.numel(): raise ValueError('DDR range')
        return raw,address-base
    def read(self,address,nbytes):
        raw,offset=self.resolve(address,nbytes); return raw[offset:offset+nbytes]
    def write(self,address,data):
        raw,offset=self.resolve(address,data.numel()); raw[offset:offset+data.numel()].copy_(data)

class Interpreter:
    def __init__(self,ddr):
        self.ddr=ddr
        self.raw=[torch.zeros(n,dtype=torch.uint8) for n in CAPACITY]
        self.desc={}; self.coverage={}; self.counts=Counter(); self.chunks=0
        self.max_used=Counter(); self.executed=0

    def descriptor(self,bank,fmt,m,n,tensor,layout=0):
        stride=stride_bytes(fmt,n,layout)
        if m*stride>CAPACITY[bank]: raise ValueError('descriptor exceeds bank')
        return Descriptor(fmt,m,n,stride,tensor,layout)

    def get(self,bank,partial=False):
        if bank not in self.desc or not self.desc[bank].valid: raise ValueError('invalid source bank')
        d=self.desc[bank]
        if d.partial and not partial: raise ValueError('incomplete reduction used as tensor')
        if d.fmt==3:
            return self.raw[bank][:d.m*d.stride].reshape(d.m,d.stride)[:,:((d.n+1)//2)]
        size=2 if d.fmt==1 else 4
        return self.raw[bank][:d.m*d.stride].view(DTYPE[d.fmt]).reshape(d.m,d.stride//size)[:,:d.n]

    def put(self,bank,x,fmt,tensor,layout=0,partial=False,next_group=0):
        m,n=x.shape
        if fmt==3: n*=2
        d=self.descriptor(bank,fmt,m,n,tensor,layout)
        self.raw[bank][:m*d.stride].zero_()
        row=x.contiguous().view(torch.uint8).reshape(m,-1)
        self.raw[bank][:m*d.stride].reshape(m,d.stride)[:,:row.shape[1]].copy_(row)
        d.valid=True;d.partial=partial;d.next_group=next_group
        self.desc[bank]=d;self.coverage.pop(bank,None)
        self.max_used[bank]=max(self.max_used[bank],m*d.stride)

    def execute(self,c):
        c=Command.decode(c.encode())
        if not c.opcode: return
        destination = c.a if c.opcode==1 else (None if c.opcode==2 else c.c)
        try:
            self._execute(c)
            for bank,flag in c.sources():
                if c.flags&flag: self.desc[bank].valid=False
        except Exception:
            if destination in self.desc: self.desc[destination].valid=False
            raise
        self.counts[list(OP)[c.opcode]]+=1;self.executed+=1

    def _execute(self,c):
        op=c.opcode
        if op==1:
            rows=c.m or c.extent_n
            if c.flags&BEGIN:
                d=self.descriptor(c.a,c.mode,rows,c.n,c.tensor,c.layout)
                self.desc[c.a]=d;self.raw[c.a][:d.m*d.stride].zero_()
                self.coverage[c.a]=torch.zeros(d.m*d.stride,dtype=torch.bool)
            d=self.desc.get(c.a)
            if d is None or (d.fmt,d.m,d.n,d.tensor,d.layout)!=(c.mode,rows,c.n,c.tensor,c.layout):
                raise ValueError('DMA descriptor mismatch')
            if c.offset+c.btt>d.m*d.stride: raise ValueError('DMA outside tensor')
            data=self.ddr.read(c.address,c.btt)
            self.raw[c.a][c.offset:c.offset+c.btt].copy_(data)
            self.coverage[c.a][c.offset:c.offset+c.btt]=True
            if c.flags&FINAL:
                if not self.coverage[c.a].all(): raise ValueError('incomplete DMA assembly')
                d.valid=True;self.coverage.pop(c.a)
            self.max_used[c.a]=max(self.max_used[c.a],d.m*d.stride)
            return
        if op==2:
            self.get(c.a)
            d=self.desc[c.a]
            if c.offset+c.btt>d.m*d.stride: raise ValueError('store outside tensor')
            self.ddr.write(c.address,self.raw[c.a][c.offset:c.offset+c.btt]); return
        a=self.get(c.a)
        if not torch.isfinite(a).all() and self.desc[c.a].fmt!=3: raise ValueError('nonfinite input')
        if op==3:
            b=self.get(c.b)
            if c.mode==0:
                q=num.unpack(b)
                s=self.get(c.scale)
                if s.shape!=(1,c.n) or not torch.isfinite(s).all() or (s<=0).any(): raise ValueError('scale')
                y=num.mul(num.dot(a,q),s)
            elif c.mode==1: y=num.dot(a,b)
            else: y=num.dot(a,b.T)
            if y.shape!=(c.m,c.n): raise ValueError('GEMM result shape')
            if c.flags&ACCUM:
                previous=self.get(c.c,partial=True); d=self.desc[c.c]
                if not d.partial or d.tensor!=c.tensor or d.next_group!=c.group or previous.shape!=y.shape:
                    raise ValueError('partial sum identity/order')
                y=num.add(previous,y)
            elif c.group: raise ValueError('INIT nonzero group')
            elif c.mode==0:
                # The hardware accumulates every W4 group into its FP32 PSUM,
                # including group0 into +0. This also canonicalizes -0 from FTZ.
                y=num.add(torch.zeros_like(y),y)
            if not torch.isfinite(y).all(): raise ValueError('GEMM overflow')
            self.put(c.c,y,2,c.tensor,c.layout,not bool(c.flags&FINAL),c.group+1);return
        if op==4: y=num.rmsnorm(a,self.get(c.b));fmt=1
        elif op==5: y=num.rope(a,self.get(c.b),c.n);fmt=1
        elif op==6: y=num.softmax(a,c.position);fmt=1
        elif op==7:
            if c.mode==VEC['BIAS']: y=num.bf16(num.add(a,self.get(c.b)));fmt=1
            elif c.mode==VEC['ADD']: y=num.bf16(num.add(a,self.get(c.b)));fmt=1
            elif c.mode==VEC['SILU_MUL']: y=num.silu_mul(a,self.get(c.b));fmt=1
            elif c.mode==VEC['DEQUANT']:
                y=num.dequant(num.unpack(a),self.get(c.b));fmt=1
            elif c.mode==VEC['CAST']: y=num.bf16(a);fmt=1
            else:
                if c.flags&INSERT:
                    if c.flags&BEGIN:
                        self.desc[c.c]=self.descriptor(c.c,1,c.extent_m,c.extent_n,c.tensor,c.layout)
                        self.coverage[c.c]=torch.zeros((c.extent_m,c.extent_n),dtype=torch.bool)
                        self.raw[c.c][:self.desc[c.c].m*self.desc[c.c].stride].zero_()
                    d=self.desc.get(c.c)
                    if d is None or d.tensor!=c.tensor or d.fmt!=1 or c.c not in self.coverage:
                        raise ValueError('assembly identity')
                    if c.row+c.m>d.m or c.col+c.n>d.n or a.shape!=(c.m,c.n):
                        raise ValueError('insert extent')
                    covered=self.coverage[c.c]
                    if covered[c.row:c.row+c.m,c.col:c.col+c.n].any(): raise ValueError('duplicate tile insertion')
                    view=self.raw[c.c][:d.m*d.stride].view(torch.bfloat16).reshape(d.m,d.stride//2)
                    view[c.row:c.row+c.m,c.col:c.col+c.n].copy_(a)
                    covered[c.row:c.row+c.m,c.col:c.col+c.n]=True
                    if c.flags&FINAL:
                        if not covered.all(): raise ValueError('incomplete tensor assembly')
                        d.valid=True;self.coverage.pop(c.c)
                    return
                if c.row+c.m>a.shape[0] or c.col+c.n>a.shape[1]: raise ValueError('extract extent')
                y=a[c.row:c.row+c.m,c.col:c.col+c.n].clone();fmt=self.desc[c.a].fmt
        else: raise ValueError('opcode')
        if not torch.isfinite(y).all(): raise ValueError('nonfinite result')
        self.put(c.c,y,fmt,c.tensor,c.layout)

    def run_chunk(self,commands):
        if not 1<=len(commands)<=1024 or commands[-1].opcode!=0 or any(c.opcode==0 for c in commands[:-1]):
            raise ValueError('complete terminal-END image required')
        for c in commands[:-1]: self.execute(c)
        self.chunks+=1

    def snapshot(self):
        return {str(k):asdict(v) for k,v in sorted(self.desc.items())}
