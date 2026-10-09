"""PS-compatible command encoding and metadata. No tensor library imports."""
from dataclasses import dataclass, asdict

OP = {'END':0, 'DMA_LOAD':1, 'DMA_STORE':2, 'GEMM':3, 'RMSNORM':4,
      'ROPE':5, 'SOFTMAX_MASKED':6, 'VECTOR':7}
FMT = {'BF16':1, 'FP32':2, 'W4':3}
VEC = {'BIAS':0, 'ADD':1, 'SILU_MUL':2, 'DEQUANT':3, 'CAST':4, 'LAYOUT':5}
INIT=1; ACCUM=2; LAST_A=4; LAST_B=8; LAST_SCALE=16; FINAL=32; BEGIN=64; INSERT=128
LAYOUT_DENSE=0; LAYOUT_ATTENTION=1
CAPACITY = [32768]*4 + [4096,4096,4096,8192,1024,131072,131072] + [8192]*7 + [65536,4096,4096,32768,4096]
# DMA prefix exactly follows cmd_dispatcher_template parameters (256,4,5,32,23,32).
FIELDS = [('opcode',252,4),('a',247,5),('b',242,5),('c',237,5),
          ('offset',205,32),('btt',182,23),('address',150,32),
          ('mode',146,4),('flags',138,8),('scale',133,5),('m',128,5),
          ('n',117,11),('k',106,11),('row',95,11),('col',82,13),
          ('position',71,11),('head',67,4),('tensor',51,16),
          ('layout',47,4),('src_layout',43,4),('group',37,6),
          ('extent_m',32,5),('extent_n',19,13)]

@dataclass(frozen=True)
class Command:
    opcode:int=0; a:int=0; b:int=0; c:int=0
    offset:int=0; btt:int=0; address:int=0
    mode:int=0; flags:int=0; scale:int=0
    m:int=0; n:int=0; k:int=0; row:int=0; col:int=0
    position:int=0; head:int=0; tensor:int=0
    layout:int=0; src_layout:int=0; group:int=0
    extent_m:int=0; extent_n:int=0

    def encode(self):
        self.check()
        word=0
        for name,start,width in FIELDS:
            value=getattr(self,name)
            if type(value) is not int or not 0 <= value < (1<<width):
                raise ValueError('field overflow: '+name)
            word |= value << start
        return word.to_bytes(32,'little')

    @classmethod
    def decode(cls,raw):
        if len(raw)!=32: raise ValueError('256-bit command required')
        word=int.from_bytes(raw,'little')
        if word & ((1<<19)-1): raise ValueError('reserved command bits')
        c=cls(**{name:(word>>start)&((1<<width)-1) for name,start,width in FIELDS})
        if c.encode()!=raw: raise ValueError('noncanonical command')
        return c

    def check(self):
        if self.opcode not in OP.values(): raise ValueError('unknown opcode')
        if self.opcode==0:
            if any(v for k,v in asdict(self).items() if k!='opcode'): raise ValueError('END operands')
            return
        if self.opcode in (1,2):
            if not 0<=self.a<23: raise ValueError('DMA bank')
            if not self.btt or self.address%8 or self.offset%16: raise ValueError('DMA alignment/length')
            if self.offset+self.btt>CAPACITY[self.a]: raise ValueError('DMA bank extent')
            if self.mode not in FMT.values() or not (self.m or self.extent_n) or not self.n: raise ValueError('DMA descriptor')
        else:
            if self.address or self.offset or self.btt: raise ValueError('compute raw address')
            if not 0<self.m<=16 or not 0<self.n<=1024: raise ValueError('compute shape')
            banks=self.operand_banks()
            if any(not 0<=x<23 for x in banks) or len(set(banks))!=len(banks):
                raise ValueError('compute bank/role alias')
            if self.opcode==3:
                if self.mode not in (0,1,2) or not 0<self.k<=1024: raise ValueError('GEMM mode/shape')
                if bool(self.flags&INIT)==bool(self.flags&ACCUM): raise ValueError('GEMM INIT xor ACCUM')
                if self.mode==0 and (self.k!=128 or self.n!=128): raise ValueError('W4 tile')
            if self.opcode==7 and self.mode not in VEC.values(): raise ValueError('vector mode')

    def operand_banks(self):
        if self.opcode in (1,2): return [self.a]
        if self.opcode==3: return [self.a,self.b,self.c]+([self.scale] if self.mode==0 else [])
        if self.opcode in (4,5): return [self.a,self.b,self.c]
        if self.opcode==6: return [self.a,self.c]
        if self.opcode==7: return [self.a,self.c]+([self.b] if self.mode in (0,1,2,3) else [])
        return []

    def sources(self):
        if self.opcode==2: return [(self.a,LAST_A)]
        if self.opcode==1: return []
        out=[(self.a,LAST_A)]
        if self.opcode in (3,4,5) or (self.opcode==7 and self.mode in (0,1,2,3)): out.append((self.b,LAST_B))
        if self.opcode==3 and self.mode==0: out.append((self.scale,LAST_SCALE))
        return out if self.opcode else []

def command(name, **kwargs): return Command(opcode=OP[name], **kwargs)

class Chunker:
    """Complete END-ended images; conservative DDR dependency boundaries.

    Does not do tensor arithmetic. All outstanding commands drain at END.
    """
    def __init__(self): self.records=[]; self.writes=[]; self.chunk_count=0
    def push(self,c):
        c.encode()
        chunks=[]
        if c.opcode==1 and any(c.address < end and start < c.address+c.btt for start,end in self.writes):
            chunks.extend(self.flush())
        if len(self.records)==1023: chunks.extend(self.flush())
        self.records.append(c)
        if c.opcode==2: self.writes.append((c.address,c.address+c.btt))
        return chunks
    def flush(self):
        if not self.records: return []
        out=self.records+[Command()]
        self.records=[]; self.writes=[]; self.chunk_count+=1
        return [out]
