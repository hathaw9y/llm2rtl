"""Local-bank fixtures for bounded executor RTL tests, not PS runtime math."""
import gzip,hashlib,json,struct
from pathlib import Path
from fractions import Fraction
from isa_codec import encode,decode,SPEC
from isa_interpreter import LAYOUT,pack16,pack32,align16
import exact_numeric as n
D=Path(__file__).resolve().parents[1]
OUT=D/'tb'/'executor_vectors'

def h(data): return hashlib.sha256(data).hexdigest()
def writehex(path,data):
    data=data+bytes((-len(data))%16)
    path.write_text(''.join(f'{int.from_bytes(data[i:i+16],"little"):032x}\n' for i in range(0,len(data),16)))

def make_case(name,record,inputs,expected,generations=(1,1,1)):
    c=decode(record); f=c['fields']; op=c['opcode']; ids=c['banks']; folder=OUT/name; folder.mkdir(parents=True,exist_ok=True)
    if op=='GEMM_INT8':
        rows,N=f['m_count'],f['n_total']; Cprofile=LAYOUT['banks'][ids[2]]['allowed_profiles'][0]
        # Bank8/9 selected profiles are gate/up, not their first cache profile.
        Cprofile={1:'projection_output',4:'Q_BF16',5:'K_BF16',6:'V_BF16',8:'gate_BF16',9:'up_BF16',12:'last_token_logits'}[ids[2]]
        selected=[2*(r*N+f['n_start']+j)+b for r in range(rows) for j in range(f['n_tile']) for b in (0,1)]
    else:
        rows=f['rows']; N=f['kv_len'] if op=='ATTN_SCORE_INT8' else 576
        Cprofile='score_BF16' if op=='ATTN_SCORE_INT8' else 'context_BF16'
        selected=list(range(len(expected)))
    bank_metadata=[]
    for slot,(index,item) in enumerate(zip(ids,inputs+[None])):
        info=LAYOUT['banks'][index]; data=bytearray(info['capacity_bytes'])
        if item:
            payload,scales,profile,ir,ic,position=item
            data[:len(payload)]=payload
            off=info['scale_region_byte_offset']; data[off:off+len(scales)]=scales
            descriptor={'present':1,'profile':SPEC['profile_encodings'][profile],'rows':ir,'cols':ic,'position':position,'layer':0,'generation':generations[slot],'data_valid':1,'scale_valid':1,'busy':1}
        else:
            data[:]=bytes([0xa5])*len(data)
            descriptor={'present':int(op=='GEMM_INT8'),'profile':SPEC['profile_encodings'][Cprofile] if op=='GEMM_INT8' else 0,'rows':rows if op=='GEMM_INT8' else 0,'cols':N if op=='GEMM_INT8' else 0,'position':0,'layer':0,'generation':generations[slot],'data_valid':0,'scale_valid':0,'busy':1}
        descriptor['owner']={'GEMM_INT8':(3,4,5),'ATTN_SCORE_INT8':(11,12,13),'ATTN_VALUE_INT8':(15,16,17)}[op][slot]
        file=f'bank{index}.hex'; writehex(folder/file,bytes(data))
        bank_metadata.append({'bank':index,'capacity_bytes':len(data),'initial_file':file,'initial_sha256':h(data),'descriptor':descriptor})
    cd=bytearray([0xa5])*LAYOUT['banks'][ids[2]]['capacity_bytes']; mask=bytearray(len(cd))
    for index in selected: cd[index]=expected[index]; mask[index]=1
    writehex(folder/'expected.hex',bytes(cd)); writehex(folder/'expected_write_mask.hex',bytes(mask))
    meta={'name':name,'hex128':f'{record:032x}','opcode':op,'fields':f,'transaction_id':0x81230000+len(cases),'generations':list(generations),'banks':bank_metadata,'expected_file':'expected.hex','expected_write_mask':'expected_write_mask.hex','expected_sha256':h(cd),'expected_write_bytes':len(selected),'expected_status':0,'producer_begin_expected':op!='GEMM_INT8','producer_generation':generations[2]+1 if op!='GEMM_INT8' else generations[2],'comparison':'entire C allocation: expected selected writes, every other byte remains0xa5; input banks must remain unchanged'}
    (folder/'case.json').write_text(json.dumps(meta,indent=2)+'\n')
    cases.append({'name':name,'path':str(folder.relative_to(D)),'metadata_sha256':h((folder/'case.json').read_bytes())})

cases=[]
def stored():
    m=json.loads((D/'verification/tensor_golden/manifest.json').read_text()); root=D/'verification/tensor_golden'
    ledger=json.loads((root/'command_ledger.json').read_text())
    chosen={}
    for v in m['vectors']:
        c=decode(int(v['hex128'],16)); f=c['fields']; op=c['opcode']; w=v['workload']; key=None
        if op=='GEMM_INT8' and w=='prefill32' and f['n_start']==0 and c['banks'][2] in (4,1):
            if c['banks'][2]==4: key='golden_prefill32_Q_K576'
            elif f['k']==1536: key='golden_prefill32_down_K1536'
        elif op=='GEMM_INT8' and w=='warm_decode32' and f['n_start']==48960: key='golden_decode_lm_head_last_N'
        elif op in ('ATTN_SCORE_INT8','ATTN_VALUE_INT8') and w in ('prefill32','warm_decode32','warm_decode33'):
            key=f'golden_{w}_{op}'
        if key and key not in chosen: chosen[key]=v
    for name,v in chosen.items():
        c=decode(int(v['hex128'],16)); f=c['fields']; op=c['opcode']; inputs=[]
        event=ledger[v['command_id']-1]
        for slot,item in enumerate(v['inputs']):
            data=gzip.decompress((root/item['components']['data']['file']).read_bytes())
            scales=gzip.decompress((root/item['components']['scale']['file']).read_bytes())
            if op=='GEMM_INT8': rows=len(data)//f['k']; cols=f['k']; pos=0
            elif slot==0: rows=f['rows']; cols=576 if op=='ATTN_SCORE_INT8' else f['kv_len']; pos=0 if op=='ATTN_SCORE_INT8' else f['query_start']
            else: rows=f['kv_len']; cols=192; pos=0
            inputs.append((data,scales,item['profile'],rows,cols,pos))
        expected=gzip.decompress((root/v['outputs']['data']['file']).read_bytes())
        make_case(name,int(v['hex128'],16),inputs,expected,tuple(event['accepted_generations']))

def directed_dense(name,M,Arows,start,Ntile,K,Nstart):
    av=[(r%63)+1 for r in range(Arows) for k in range(K)]
    bv=[2+(j%5) for j in range(Ntile) for k in range(K)]
    sa=[n.f32(Fraction(1+2*g,128)) for g in range((Arows+15)//16)]
    sb=[n.f32(Fraction(1+g,256)) for g in range((Ntile+15)//16)]
    expected=[0]*(M*576)
    for r in range(M):
        for j in range(Ntile):
            dot=sum(av[(start+r)*K+k]*bv[j*K+k] for k in range(K))
            expected[r*576+Nstart+j]=n.scaled_output(dot,sa[(start+r)//16],sb[j//16])
    make_case(name,encode('GEMM_INT8',(13,15,1),n_start=Nstart,n_total=576,m_start=start,m_count=M,k=K,n_tile=Ntile),
      [(bytes(av),pack32(sa)+bytes((-len(sa)*4)%16),'A_INT8',Arows,K,0),(bytes(bv),pack32(sb)+bytes((-len(sb)*4)%16),'weight_INT8',Ntile,K,0)],pack16(expected))

def directed_attention():
    rows,L,pos=17,33,16; stride=align16(L)
    q=bytes((127 if h%2==0 else 129) for r in range(rows) for h in range(9) for d in range(64))
    sa=[n.f32(Fraction(1+g+h%3,128)) for h in range(9) for g in range(2)]; sb=[n.f32(Fraction(h+1,256)) for h in range(3)]
    expected=[0]*(rows*9*stride)
    for r in range(rows):
        for h in range(9):
            value=n.scaled_output(64*127*127*(1 if h%2==0 else -1),sa[h*2+r//16],sb[h//3],True)
            for t in range(pos+r+1): expected[(r*9+h)*stride+t]=value
    make_case('direct_QK_M17_L33_scale_groups',encode('ATTN_SCORE_INT8',(14,8,10),rows=rows,kv_len=L,query_start=pos),
      [(q,pack32(sa)+bytes((-len(sa)*4)%16),'Q_INT8',rows,576,0),(bytes([127])*(L*192),pack32(sb)+bytes(4),'K_current_or_cache_INT8',L,192,0)],pack16(expected))
    rows,L,pos=1,1024,1023
    sa=[n.f32(Fraction(1+h%3,128)) for h in range(9)]; sb=[n.f32(Fraction(1+g,128)) for h in range(3) for g in range(4)]
    expected=[n.scaled_output(L*127*127,sa[h],sb[(h//3)*4+d//16]) for h in range(9) for d in range(64)]
    make_case('direct_PV_L1024_INT32_max',encode('ATTN_VALUE_INT8',(13,9,11),rows=rows,kv_len=L,query_start=pos),
      [(bytes([127])*(9*L),pack32(sa)+bytes(12),'probability_INT8',1,L,pos),(bytes([127])*(L*192),pack32(sb),'V_current_or_cache_INT8',L,192,0)],pack16(expected))

def directed_small_and_underflow():
    sa=[n.f32(Fraction(h+1,128)) for h in range(9)]
    sb=[n.f32(Fraction(h+1,256)) for h in range(3)]
    q=bytes(127 if h%2==0 else 129 for h in range(9) for d in range(64))
    expected=[0]*(9*16)
    for h in range(9): expected[h*16]=n.scaled_output(64*127*127*(1 if h%2==0 else -1),sa[h],sb[h//3],True)
    make_case('direct_QK_L1_padded16',encode('ATTN_SCORE_INT8',(14,8,10),rows=1,kv_len=1,query_start=0),
      [(q,pack32(sa)+bytes(12),'Q_INT8',1,576,0),(bytes([127])*192,pack32(sb)+bytes(4),'K_current_or_cache_INT8',1,192,0)],pack16(expected))
    sa=[n.f32(Fraction(1,127))]*9
    sb=[n.f32(Fraction(1+g,128)) for h in range(3) for g in range(4)]
    v=bytes(127 if h%2==0 else 129 for h in range(3) for d in range(64))
    expected=[n.scaled_output(127*127*(1 if h//3%2==0 else -1),sa[h],sb[(h//3)*4+d//16]) for h in range(9) for d in range(64)]
    make_case('direct_PV_L1_tail',encode('ATTN_VALUE_INT8',(13,9,11),rows=1,kv_len=1,query_start=0),
      [(bytes(v for h in range(9) for v in ([127]+[0]*15)),pack32(sa)+bytes(12),'probability_INT8',1,1,0),(v,pack32(sb),'V_current_or_cache_INT8',1,192,0)],pack16(expected))
    expected=[0]*576; expected[64]=0x8000
    assert n.scaled_output(-576*127*127,1,1)==0x8000
    make_case('direct_combined_scale_underflow_negzero',encode('GEMM_INT8',(13,15,1),n_start=64,n_total=576,m_count=1,k=576,n_tile=1),
      [(bytes([129])*576,pack32([1])+bytes(12),'A_INT8',1,576,0),(bytes([127])*576,pack32([1])+bytes(12),'weight_INT8',1,576,0)],pack16(expected))

def directed_QK_context_max():
    sa=[n.f32(Fraction(h+1,128)) for h in range(9)]
    sb=[n.f32(Fraction(h+1,256)) for h in range(3)]
    q=bytes(127 if h%2==0 else 129 for h in range(9) for d in range(64))
    expected=[n.scaled_output(64*127*127*(1 if h%2==0 else -1),sa[h],sb[h//3],True)
              for h in range(9) for token in range(1024)]
    make_case('direct_QK_L1024_cache_end',encode('ATTN_SCORE_INT8',(14,8,10),rows=1,kv_len=1024,query_start=1023),
      [(q,pack32(sa)+bytes(12),'Q_INT8',1,576,0),(bytes([127])*(1024*192),pack32(sb)+bytes(4),'K_current_or_cache_INT8',1024,192,0)],pack16(expected))

if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True); stored()
    directed_dense('direct_m_start31_N1',1,32,31,1,576,64)
    directed_dense('direct_M17_N17_K1536',17,17,0,17,1536,64)
    directed_attention()
    directed_small_and_underflow()
    directed_QK_context_max()
    manifest={'schema':'llm2rtl.executor_vectors.v1','scope':'local bank standalone executor tests, exact frozen arithmetic; no full-model/board claim','cases':cases,'count':len(cases),'source_sha256':h(Path(__file__).read_bytes()),'golden_manifest_sha256':h((D/'verification/tensor_golden/manifest.json').read_bytes())}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n'); print(json.dumps({'cases':len(cases),'path':str(OUT)},indent=2))
