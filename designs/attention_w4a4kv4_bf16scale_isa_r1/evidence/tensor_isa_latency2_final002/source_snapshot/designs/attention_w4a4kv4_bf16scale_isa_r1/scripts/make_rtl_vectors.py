"""Prepare source-identified whole-program bank vectors for real RTL simulation."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
sys.path.insert(0,str(ROOT/'python'))
import isa_program as isa
import attention_hardware_reference as hw

PROFILES = {
    'prefill': dict(tokens=3,inputs=33,heads=2,head_dim=16,outputs=33),
    'last_token': dict(tokens=3,inputs=33,heads=2,head_dim=16,outputs=33,query_indices=[2]),
    'odd_head': dict(tokens=4,inputs=35,heads=3,head_dim=11,outputs=17),
    'noncausal_mask': dict(tokens=4,inputs=9,heads=2,head_dim=3,outputs=7,causal=False,query_indices=[3,0,3]),
    'all_masked': dict(tokens=3,inputs=5,heads=1,head_dim=3,outputs=5),
    'zero': dict(tokens=2,inputs=3,heads=1,head_dim=2,outputs=3),
    'gentle': dict(tokens=4,inputs=33,heads=3,head_dim=11,outputs=17),
    'max_tokens': dict(tokens=32,inputs=33,heads=2,head_dim=3,outputs=7),
    'max_row': dict(tokens=1,inputs=256,heads=4,head_dim=64,outputs=1),
}

def write_words(path,payload):
    if len(payload)%16:
        raise ValueError('unaligned tensor payload')
    path.write_text(''.join(f'{int.from_bytes(payload[i:i+16],"little"):032x}\n' for i in range(0,len(payload),16)))

def generate(profile,out):
    out=Path(out)
    out.mkdir(parents=True,exist_ok=True)
    cfg,words=isa.compile_program(**PROFILES[profile])
    tokens,inputs=cfg['banks'][0]['shape']
    width=cfg['heads']*cfg['head_dim']
    outputs=cfg['banks'][-1]['shape'][-1]
    rng=np.random.RandomState(41)
    x=rng.normal(size=(tokens,inputs)).astype(np.float32)
    ws=[rng.normal(size=(width,inputs)).astype(np.float32) for _ in range(3)]
    wo=rng.normal(size=(outputs,width)).astype(np.float32)
    if profile=='gentle':
        x *= np.float32(.1)
        ws = [w*np.float32(.1) for w in ws]
        wo *= np.float32(.1)
    mask=np.ones(tokens,np.uint8)
    if profile=='noncausal_mask':
        mask[:]=[1,0,1,0]
    elif profile=='all_masked':
        mask.fill(0)
    elif profile=='zero':
        x.fill(0)
    initial=isa.prepare(cfg,x,*ws,wo,mask)
    result=hw.attention(x,*ws,wo,cfg['heads'],cfg['causal'],mask,cfg['query_indices'])
    packed=hw.pack_banks(cfg,result)
    mathematical=isa.ref.attention(x,*ws,wo,cfg['heads'],cfg['causal'],mask.astype(bool),cfg['query_indices'])
    ap=(result['probabilities_bf16'].astype(np.uint32)<<16).view(np.float32)
    mp=(mathematical['probabilities_bf16'].astype(np.uint32)<<16).view(np.float32)
    error=float(np.max(np.abs(ap-mp)))
    if error>0.00390625:
        raise AssertionError('BF16 mathematical probability bound exceeded')
    (out/'descriptor_table.json').write_text(json.dumps(cfg,indent=2)+'\n')
    (out/'program.mem').write_text(''.join(f'{x:032x}\n' for x in words))
    (out/'program.bin').write_bytes(b''.join(w.to_bytes(16,'little') for w in words))
    for d in cfg['banks']:
        if d['name'] in cfg['ddr_addresses'] and d['name']!='output4':
            payload=initial[cfg['ddr_addresses'][d['name']]]
            write_words(out/f"input_bank{d['bank']:02d}.mem",payload)
            (out/f"input_bank{d['bank']:02d}.bin").write_bytes(payload)
        if d['bank'] in packed:
            write_words(out/f"expected_bank{d['bank']:02d}.mem",packed[d['bank']])
            (out/f"expected_bank{d['bank']:02d}.bin").write_bytes(packed[d['bank']])
    # A distinct diagnostic program exports every computed tensor through legal
    # S2MM commands before END. The original 21-command program stays intact.
    debug_words = words[:-1]
    debug_addresses = {}
    cursor = 0x20000000
    for bank in sorted(packed):
        debug_addresses[str(bank)] = cursor
        debug_words.append(isa.encode('S2MM',src0=bank,descriptor=bank,immediate=cursor))
        cursor += cfg['banks'][bank]['capacity_bytes']
    debug_words.append(isa.encode('END'))
    (out/'diagnostic_program.mem').write_text(''.join(f'{w:032x}\n' for w in debug_words))
    (out/'diagnostic_ddr_addresses.json').write_text(json.dumps(debug_addresses,indent=2)+'\n')
    np.savez(out/'reference_inputs.npz',x=x,wq=ws[0],wk=ws[1],wv=ws[2],wo=wo,mask=mask)
    report=dict(profile=profile,status='GOLDEN_PREPARED_NOT_RTL_PASS',instruction_count=len(words),
        approximation='exp2 interpolation relative bound1e-5/cutoff-80',probability_absolute_error=error,
        final_int4_difference_max=int(np.max(np.abs(result['output4']-mathematical['output4']))),
        capacity_bytes=sum(d['capacity_bytes'] for d in cfg['banks']),
        initial_banks=list(range(6)),expected_banks=sorted(packed))
    sources=[Path(__file__),ROOT/'isa_program.py',ROOT/'python/attention_hardware_reference.py',
             isa.LEGACY/'python/attention_reference.py',isa.LEGACY/'reference/quantizer_reference.py']
    report['source_hashes']={str(p.resolve()):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
    report['artifact_hashes']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.iterdir()) if p.name!='golden_report.json'}
    (out/'golden_report.json').write_text(json.dumps(report,indent=2)+'\n')
    return report

if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--profile',choices=PROFILES,required=True)
    p.add_argument('--out',type=Path,required=True)
    args=p.parse_args()
    r=generate(args.profile,args.out)
    print(r['status'],r['profile'],'probability_error='+str(r['probability_absolute_error']))
