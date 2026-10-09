"""Reproducible synthetic one-block ISA execution; not model quality validation.

The fixture includes all SmolLM2 matrix widths and a full 49152-entry lm_head.
Input images are synthetic prepared data. PS-side fixture construction does not
represent a runtime tensor fallback. Nonlinear outputs are reference oracles.
"""
import gzip
import struct
import hashlib
import json
from pathlib import Path
from fractions import Fraction
from isa_interpreter import Interpreter, pack16, pack32, DESIGN
from isa_codec import encode, encode_weight_fragments
from integer_matrix import BACKEND
import exact_numeric as num

class Fixture:
    def __init__(self, output):
        self.output=output; output.mkdir(parents=True,exist_ok=True)
        self.i=Interpreter(); self.next_address=0x10000000
        self.images={}; self.vectors=[]; self.workload=''; self.sequence=0; self.fragment_count=0
        self.gamma=self.map('gamma',pack16([num.bf16(1)]*576))
        static=b''.join(pack32([num.f32(Fraction(h+1,64)) for h in range(3)])+bytes(4)+
                        pack32([num.f32(Fraction(g+1,128)) for h in range(3) for g in range(4)])
                        for _ in range(30))
        self.static=self.map('static_KV_scales',static)
        self.rope=self.map('synthetic_rope_identity',pack16(([num.bf16(1)]*32+[0]*32)*1024))
        self.cacheK=self.map('cache_K',bytes(1024*192)); self.cacheV=self.map('cache_V',bytes(1024*192))
        self.logits=self.map('logits_output',bytes(49152*2))
        self.weights={}
        for name,N,K in [('q',576,576),('k',192,576),('v',192,576),('o',576,576),
                         ('gate',1536,576),('up',1536,576),('down',576,1536),('tied_embedding_lm_head',49152,576)]:
            pattern=bytes(((r%7-3)*(d%5-2))&255 for r in range(7) for d in range(K))
            data=(pattern*((N+6)//7))[:N*K]
            scales=pack32([num.f32(Fraction(1+(g%3),256)) for g in range((N+15)//16)])
            self.weights[name]=(self.map(name+'_INT8',data),self.map(name+'_scales',scales),N,K)

    def map(self,name,data):
        address=self.next_address; self.next_address+=(len(data)+4095)//4096*4096
        self.i.ddr.map(address,data,name)
        self.images[name]={'address':address,'byte_count':len(data),'initial_sha256':hashlib.sha256(data).hexdigest()}
        return address

    def issue(self,record):
        if record and self.fragment_count == 15: self.issue(0)
        self.fragment_count = self.fragment_count+1 if record else 0
        from isa_codec import decode
        decoded=decode(record); opcode=decoded['opcode']
        compute=opcode in ('QUANTIZE','DEQUANTIZE','GEMM_INT8','ATTN_SCORE_INT8','ATTN_VALUE_INT8','RMSNORM','ADD','SILU_MUL','SOFTMAX','ROPE')
        inputs=[]
        if compute:
            positions=[0] if opcode in ('DEQUANTIZE','SOFTMAX','QUANTIZE') else [0,1]
            if opcode=='QUANTIZE' and decoded['fields']['mode'] in (2,3): positions.append(1)
            for position in positions:
                bankid=decoded['banks'][position]; bank=self.i.banks[bankid]
                components={}
                for key,(lo,hi) in bank.ranges.items():
                    if bankid==7 and key != ('static' if opcode=='QUANTIZE' else 'rope'): continue
                    data=bytes(bank.data[lo:hi])
                    stem=f'{self.sequence+1:04d}_{self.workload}_{opcode}_input_B{bankid}_{key}.bin.gz'
                    (self.output/stem).write_bytes(gzip.compress(data,mtime=0))
                    components[key]={'file':stem,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
                inputs.append({'bank':bankid,'profile':bank.name,'generation':bank.generation,'components':components})
        event=self.i.step(record)
        if event['opcode'] in ('QUANTIZE','DEQUANTIZE','GEMM_INT8','ATTN_SCORE_INT8','ATTN_VALUE_INT8','RMSNORM','ADD','SILU_MUL','SOFTMAX','ROPE'):
            self.sequence+=1
            from isa_codec import decode
            cmd=decode(record); bankid=cmd['banks'][0] if event['opcode'] in ('SOFTMAX','ROPE') else cmd['banks'][2]
            bank=self.i.banks[bankid]
            # A partial GEMM destination includes a coverage bitmap. Unwritten
            # bytes are excluded from numerical comparison by this bitmap.
            files={}
            for key,(lo,hi) in bank.ranges.items():
                stem=f'{self.sequence:04d}_{self.workload}_{event["opcode"]}_B{bankid}_{key}'
                data=bytes(bank.data[lo:hi]); coverage=bytes(bank.coverage[lo:hi])
                (self.output/(stem+'.bin.gz')).write_bytes(gzip.compress(data,mtime=0))
                (self.output/(stem+'.coverage.bin.gz')).write_bytes(gzip.compress(coverage,mtime=0))
                files[key]={'file':stem+'.bin.gz','coverage_file':stem+'.coverage.bin.gz','encoding':'gzip; little-endian native bank bytes','sha256':hashlib.sha256(data).hexdigest(),'coverage_sha256':hashlib.sha256(coverage).hexdigest(),'bytes':len(data)}
            self.vectors.append({'command_id':event['command_id'],'workload':self.workload,'opcode':event['opcode'],
                                 'hex128':event['hex128'],'inputs':inputs,'output_bank':bankid,'output_profile':bank.name,'outputs':files})

    def load(self,bank,offset,count,address,aux=0):
        self.issue(encode('DMA_LOAD',(bank,0,0),local_byte_offset=offset,byte_count=count,ddr_address=address,aux=aux))

    def store(self,bank,offset,count,address):
        self.issue(encode('DMA_STORE',(bank,0,0),local_byte_offset=offset,byte_count=count,ddr_address=address))

    def quant(self,source,destination,mode,rows,k,start=0,position=0,length=0):
        self.issue(encode('QUANTIZE',(source,7 if mode in (2,3) else 0,destination),mode=mode,m_start=start,m_count=rows,k=k,query_start=position,kv_len=length))

    def gemm(self,name,bank,profile,rows):
        data,scales,N,K=self.weights[name]
        self.issue(self.i.config(bank,profile,rows,N))
        epoch=max(self.i.banks[b].generation for b in (3,15))
        for fragment in encode_weight_fragments(N,K,rows,data,scales,bank,first_epoch=epoch):
            for record in fragment: self.issue(record)

    def norm(self,source,rows):
        self.issue(self.i.config(3,'gamma_BF16',1,576)); self.load(3,0,1152,self.gamma)
        self.issue(encode('RMSNORM',(source,3,2),rows=rows))

    def workload_run(self,rows,position,label):
        self.workload=label; begin=len(self.i.ledger)
        data,scales,_,_=self.weights['tied_embedding_lm_head']
        self.issue(self.i.config(3,'embedding_rows_INT8',rows,576))
        for row in range(rows):
            token=(position+row)*19+7
            self.load(3,row*576,576,data+token*576)
            self.load(3,294912+row*16,16,scales+(token//64)*16,1|((token//16)%4<<1))
        self.issue(encode('DEQUANTIZE',(3,0,0),m_count=rows,k=576))
        self.issue(self.i.config(7,'RoPE_and_static_KV_scales',rows,64,position=position,component=1))
        self.load(7,0,rows*128,self.rope+position*128)
        self.norm(0,rows); self.quant(2,13,0,rows,576)
        for name,bank,profile in [('q',4,'Q_BF16'),('k',5,'K_BF16'),('v',6,'V_BF16')]: self.gemm(name,bank,profile,rows)
        for bank in (4,5): self.issue(encode('ROPE',(bank,7,0),rows=rows))
        self.quant(4,14,1,rows,64); self.quant(5,8,2,rows,64); self.quant(6,9,3,rows,64)
        self.store(8,0,rows*192,self.cacheK+position*192); self.store(9,0,rows*192,self.cacheV+position*192)
        self.issue(encode('FENCE'))
        length=position+rows
        for bank,profile,address,scaleoff,scalebytes in [(8,'K_current_or_cache_INT8',self.cacheK,0,16),(9,'V_current_or_cache_INT8',self.cacheV,16,48)]:
            self.issue(self.i.config(bank,profile,length,192)); self.load(bank,0,length*192,address)
            self.load(bank,196608,scalebytes,self.static+scaleoff)
        f=dict(rows=rows,query_start=position,kv_len=length)
        self.issue(encode('ATTN_SCORE_INT8',(14,8,10),**f)); self.issue(encode('SOFTMAX',(10,0,0),**f))
        self.quant(10,13,4,rows,length,position=position,length=length)
        self.issue(encode('ATTN_VALUE_INT8',(13,9,11),**f)); self.quant(11,13,0,rows,576)
        self.gemm('o',1,'projection_output',rows); self.issue(encode('ADD',(0,1,5),rows=rows))
        self.norm(5,rows); self.quant(2,13,0,rows,576)
        self.gemm('gate',8,'gate_BF16',rows); self.gemm('up',9,'up_BF16',rows)
        self.issue(encode('SILU_MUL',(8,9,10),rows=rows)); self.quant(10,13,0,rows,1536)
        self.gemm('down',1,'projection_output',rows); self.issue(encode('ADD',(5,1,0),rows=rows))
        self.norm(0,rows); self.quant(2,13,0,1,576,start=rows-1)
        self.gemm('tied_embedding_lm_head',12,'last_token_logits',1); self.store(12,0,98304,self.logits)
        self.issue(encode('END'))
        return {'name':label,'rows':rows,'position':position,'kv_len':length,'commands':len(self.i.ledger)-begin,
                'logits_sha256':hashlib.sha256(self.i.ddr.read(self.logits,98304)).hexdigest()}

    def run(self):
        self.issue(self.i.config(7,'RoPE_and_static_KV_scales',30,64,component=2)); self.load(7,4096,1920,self.static)
        workloads=[self.workload_run(32,0,'prefill32'),self.workload_run(1,32,'warm_decode32'),self.workload_run(1,33,'warm_decode33')]
        ledger=self.output/'command_ledger.json'; ledger.write_text(json.dumps(self.i.ledger,indent=2)+'\n')
        program=b''.join(int(e['hex128'],16).to_bytes(16,'little') for e in self.i.ledger)
        (self.output/'program.bin').write_bytes(program)
        fragments=[]; start=0
        for index,event in enumerate(self.i.ledger):
            if event['opcode']=='END':
                assert index-start<=15
                fragments.append({'byte_offset':start*16,'record_count':index-start+1})
                start=index+1
        assert start==len(self.i.ledger)
        manifest={'schema':'llm2rtl.synthetic_tensor_golden.v1','status':'PASS_SYNTHETIC_ONE_BLOCK',
          'scope':'one synthetic decoder block at exact model widths plus full lm_head; prefill32 and two warm decode steps',
          'excluded_claims':['30-layer checkpoint numerical validation','calibration or model quality','nonlinear RTL equivalence','RTL simulation','cycle/AXI timing','FPGA resources or board pass'],
          'program':{'file':'program.bin','sha256':hashlib.sha256(program).hexdigest(),'record_bytes':16,'byte_order':'little','fragments':fragments},
          'integer_backend':BACKEND,'prepared_images':self.images,'workloads':workloads,'vectors':self.vectors,
          'command_ledger_sha256':hashlib.sha256(ledger.read_bytes()).hexdigest(),
          'reference_nonlinear_opcodes':sorted(self.i.reference_nonlinear_used),
          'source_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (DESIGN/'scripts').glob('*.py')},
          'contract_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (DESIGN/'contracts').glob('*.json')}}
        (self.output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
        return {'status':manifest['status'],'workloads':workloads,'vectors':len(self.vectors),'commands':len(self.i.ledger)}

if __name__=='__main__':
    print(json.dumps(Fixture(DESIGN/'verification'/'tensor_golden').run(),indent=2))
