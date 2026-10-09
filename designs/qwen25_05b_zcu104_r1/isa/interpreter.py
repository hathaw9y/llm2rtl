"""Sequential tensor ISA reference. This is not an RTL or cycle-accurate simulator.

Only DMA handles DDR addresses. Arithmetic handlers accept logical bank IDs.
The compiler emits address/shape commands; all runtime tensor math lives here.
"""
from collections import Counter
from bisect import bisect_right
from dataclasses import dataclass, asdict
import torch
import torch.nn.functional as F

DTYPES={'BF16':torch.bfloat16,'FP32':torch.float32,'U8':torch.uint8}
BANK_BYTES={0:65536,1:327680,2:65536,3:16384,4:65536,5:65536,
            6:65536,7:65536,8:524288,9:524288,10:16384,11:16384}
OPCODES={'END':0,'DMA_LOAD':1,'DMA_STORE':2,'GEMM_W4':3,'DEQUANT':4,
         'RMSNORM':5,'ROPE':6,'ATTENTION':7,'ADD':8,'SILU_MUL':9,'CAST':10}
ARITIES={'END':(0,0),'DMA_LOAD':(1,0),'DMA_STORE':(1,0),'GEMM_W4':(5,4),
         'DEQUANT':(3,4),'RMSNORM':(3,2),'ROPE':(4,3),'ATTENTION':(4,4),
         'ADD':(3,2),'SILU_MUL':(3,2),'CAST':(2,2)}

# One 512-bit fixed record. Slots are opcode-specific, not pointer descriptors.
# Header 32 bits; six bank IDs (8 bits each); six u32 parameters; u64 DDR address;
# four u32 DMA strides/extents; final 48 reserved bits.
@dataclass(frozen=True)
class Command:
    opcode:str
    banks:tuple=()
    params:tuple=()
    address:int=0
    dma:tuple=()
    tag:int=0
    flags:int=0

    def encode(self):
        if self.opcode not in OPCODES or (len(self.banks),len(self.params))!=ARITIES[self.opcode]:
            raise ValueError('unencodable command')
        if self.opcode not in ('DMA_LOAD','DMA_STORE') and (self.address or self.dma):
            raise ValueError('only DMA may address DDR')
        if not 0<=self.tag<65536 or self.flags!=0:
            raise ValueError('header overflow')
        if self.opcode in ('DMA_LOAD','DMA_STORE'):
            if len(self.dma)!=4 or self.dma[3]!=0 or min(self.dma[:3])<=0 or self.dma[2]<self.dma[1]:
                raise ValueError('invalid DMA extent/stride/reserved field')
        if any(n<=0 for n in self.params) and self.opcode!='ATTENTION':
            raise ValueError('nonpositive dimension')
        if self.opcode=='ATTENTION':
            m,length,start,d=self.params
            if d!=64 or m<1 or m>4 or start<0 or length!=start+m or length>2048:
                raise ValueError('unsupported attention domain')
        if self.opcode=='ROPE' and (self.params[1] not in (2,14) or self.params[2]!=64):
            raise ValueError('unsupported RoPE domain')
        if self.opcode=='DEQUANT' and self.params[0]!=1:
            raise ValueError('DEQUANT first dimension must be one')
        if self.opcode in ('GEMM_W4','DEQUANT') and self.params[3] not in (32,128):
            raise ValueError('unsupported quantization group size')
        if self.opcode=='END' and self.banks:
            raise ValueError('END has operands')
        out=bytearray([OPCODES[self.opcode],self.flags])+bytearray(self.tag.to_bytes(2,'little'))
        for n in self.banks:
            if n not in BANK_BYTES: raise ValueError('unknown bank')
        out.extend(bytes(self.banks)+(b'\xff'*(6-len(self.banks))))
        for n in self.params+(0,)*(6-len(self.params)): out.extend(n.to_bytes(4,'little'))
        out.extend(self.address.to_bytes(8,'little'))
        for n in self.dma+(0,)*(4-len(self.dma)): out.extend(n.to_bytes(4,'little'))
        out.extend(b'\0'*6)
        assert len(out)==64
        return bytes(out)

    @classmethod
    def decode(cls,raw):
        if len(raw)!=64:raise ValueError('record must be 64 bytes')
        names={v:k for k,v in OPCODES.items()}
        if raw[0] not in names or any(raw[58:]):raise ValueError('unknown opcode/reserved bits')
        op=names[raw[0]];nb,np=ARITIES[op]
        if any(x!=255 for x in raw[4+nb:10]):raise ValueError('noncanonical bank padding')
        params=tuple(int.from_bytes(raw[10+i*4:14+i*4],'little') for i in range(6))
        if any(params[np:]):raise ValueError('nonzero parameter padding')
        dma=tuple(int.from_bytes(raw[42+i*4:46+i*4],'little') for i in range(4))
        c=cls(op,tuple(raw[4:4+nb]),params[:np],int.from_bytes(raw[34:42],'little'),
              dma if op in ('DMA_LOAD','DMA_STORE') else (),
              int.from_bytes(raw[2:4],'little'),raw[1])
        if op not in ('DMA_LOAD','DMA_STORE') and any(dma):raise ValueError('compute has DMA fields')
        if c.encode()!=raw:raise ValueError('noncanonical record')
        return c

class DDR:
    """Synthetic address space for software validation; not board address assignment."""
    def __init__(self): self.regions=[]; self.starts=[];self.names={};self.next=0x10000000
    def allocate(self,name,tensor,capacity_nbytes=None):
        raw=tensor.contiguous().view(torch.uint8).reshape(-1).clone()
        if name in self.names:
            address,old=self.names[name]
            if raw.numel()>old.numel():raise ValueError('scratch resize exceeds provisioned capacity')
            old[:raw.numel()].copy_(raw);return address
        if capacity_nbytes is not None:
            if capacity_nbytes<raw.numel():raise ValueError('allocation capacity too small')
            expanded=torch.zeros(capacity_nbytes,dtype=torch.uint8)
            expanded[:raw.numel()].copy_(raw);raw=expanded
        address=(self.next+127)//128*128
        self.regions.append((address,name,raw)); self.starts.append(address);self.names[name]=(address,raw);self.next=address+raw.numel()
        return address
    def resolve(self,address,nbytes):
        index=bisect_right(self.starts,address)-1
        if index>=0 and nbytes>0:
            base,name,raw=self.regions[index]
            if address+nbytes<=base+raw.numel():return raw,address-base
        raise ValueError('DMA outside allocated DDR region')
    def read(self,address,nbytes):
        raw,offset=self.resolve(address,nbytes);return raw[offset:offset+nbytes].clone()
    def write(self,address,data):
        raw,offset=self.resolve(address,data.numel());raw[offset:offset+data.numel()].copy_(data)
    def tensor(self,address,shape,fmt='BF16'):
        count=1
        for d in shape:count*=d
        size=torch.empty((),dtype=DTYPES[fmt]).element_size()
        return self.read(address,count*size).view(DTYPES[fmt]).reshape(shape)

class Interpreter:
    def __init__(self,ddr):
        self.ddr=ddr;self.banks={};self.counts=Counter();self.commands=[];self.max_bytes=Counter()
    def put(self,bank,tensor):
        raw=tensor.contiguous().view(torch.uint8).reshape(-1).clone()
        if raw.numel()>BANK_BYTES[bank]:raise ValueError('bank capacity exceeded')
        self.banks[bank]=raw;self.max_bytes[bank]=max(self.max_bytes[bank],raw.numel())
    def get(self,bank,shape,fmt='BF16'):
        if bank not in self.banks:raise ValueError('source bank invalid')
        value=self.banks[bank].view(DTYPES[fmt])
        count=1
        for n in shape:count*=n
        if value.numel()!=count:raise ValueError('extent/format mismatch')
        return value.reshape(shape)
    @staticmethod
    def dequant(q,scale,rows,k,group):
        # INT4 sign extension is explicit; -8 is reserved/rejected.
        if not torch.isfinite(scale).all() or (scale<=0).any():raise ValueError('invalid quantization scale')
        if k%2 and (q[:,-1]>>4).any():raise ValueError('nonzero odd-K padding')
        pairs=torch.stack((q&15,q>>4),dim=-1).flatten(-2)[...,:k].to(torch.int8)
        signed=torch.where(pairs>=8,pairs-16,pairs)
        if (signed==-8).any():raise ValueError('reserved INT4 code')
        expanded=scale.float().repeat_interleave(group,dim=-1)[...,:k]
        return (signed.float()*expanded).to(torch.bfloat16).reshape(rows,k)
    def run(self,commands):
        if not commands or commands[-1].opcode!='END':raise ValueError('missing terminal END')
        for index,c in enumerate(commands):
            c=Command.decode(c.encode())
            if c.opcode=='END' and index!=len(commands)-1:raise ValueError('early END')
            if len(c.banks)!=len(set(c.banks)):raise ValueError('aliased operand banks')
            # Execute into temporary tensors. Commit destination only after success.
            b=c.banks;p=c.params;op=c.opcode
            if op=='DMA_LOAD':
                rows,rowbytes,ddr_stride,_=c.dma
                if rows*rowbytes>BANK_BYTES[b[0]]:raise ValueError('bank capacity exceeded')
                pieces=[self.ddr.read(c.address+i*ddr_stride,rowbytes) for i in range(rows)]
                out=torch.cat(pieces);dst=b[0]
            elif op=='DMA_STORE':
                rows,rowbytes,ddr_stride,_=c.dma
                raw=self.banks[b[0]]
                if raw.numel()!=rows*rowbytes:raise ValueError('DMA store extent mismatch')
                # Validate all ranges before the first external write.
                for i in range(rows):self.ddr.resolve(c.address+i*ddr_stride,rowbytes)
                for i in range(rows):self.ddr.write(c.address+i*ddr_stride,raw[i*rowbytes:(i+1)*rowbytes])
                out=None
            elif op in ('GEMM_W4','DEQUANT'):
                m,n,k,group=p[:4]
                qb=b[1] if op=='GEMM_W4' else b[0]
                sb=b[2] if op=='GEMM_W4' else b[1]
                w=self.dequant(self.get(qb,(n,(k+1)//2),'U8'),
                    self.get(sb,(n,(k+group-1)//group)),n,k,group)
                if op=='DEQUANT':out=w;dst=b[2]
                else:
                    a=self.get(b[0],(m,k)).float()
                    bias=self.get(b[3],(n,)).float()
                    out=(F.linear(a,w.float(),bias)).to(torch.bfloat16);dst=b[4]
            elif op=='RMSNORM':
                m,k=p[:2];x=self.get(b[0],(m,k));gamma=self.get(b[1],(k,))
                f=x.float();out=(gamma*(f*torch.rsqrt((f*f).mean(-1,keepdim=True)+1e-6)).to(x.dtype));dst=b[2]
            elif op=='ROPE':
                m,h,d=p[:3];x=self.get(b[0],(m,h*d)).view(m,h,d).transpose(0,1).unsqueeze(0)
                cos=self.get(b[1],(m,d)).unsqueeze(0).unsqueeze(0)
                sin=self.get(b[2],(m,d)).unsqueeze(0).unsqueeze(0)
                half=torch.cat((-x[...,d//2:],x[...,:d//2]),-1)
                out=(x*cos+half*sin).squeeze(0).transpose(0,1).reshape(m,h*d);dst=b[3]
            elif op=='ATTENTION':
                m,length,start,d=p[:4]
                q=self.get(b[0],(m,14*d)).view(m,14,d).transpose(0,1)
                k=self.get(b[1],(length,2*d)).view(length,2,d)
                v=self.get(b[2],(length,2*d)).view(length,2,d)
                heads=[]
                # One Q row/head at a time: no full T-by-T score allocation.
                for h in range(14):
                    kh=k[:,h//7].T;vh=v[:,h//7]
                    values=[]
                    for row in range(m):
                        score=(q[h,row:row+1].float()@kh.float()).to(torch.bfloat16)
                        score=(score/8).to(torch.bfloat16)
                        mask=torch.arange(length)>start+row
                        score=score.masked_fill(mask.unsqueeze(0),torch.finfo(torch.bfloat16).min)
                        prob=F.softmax(score.float(),dim=-1).to(torch.bfloat16)
                        values.append((prob.float()@vh.float()).to(torch.bfloat16))
                    heads.append(torch.cat(values))
                out=torch.stack(heads,dim=1).reshape(m,14*d);dst=b[3]
            elif op in ('ADD','SILU_MUL'):
                m,k=p[:2];a=self.get(b[0],(m,k));other=self.get(b[1],(m,k))
                out=a+other if op=='ADD' else F.silu(a)*other;dst=b[2]
            elif op=='CAST':
                m,k=p[:2];out=self.get(b[0],(m,k)).float();dst=b[1]
            elif op=='END':out=None
            else:raise ValueError('unsupported opcode')
            if out is not None:self.put(dst,out)
            self.counts[op]+=1;self.commands.append(c)
