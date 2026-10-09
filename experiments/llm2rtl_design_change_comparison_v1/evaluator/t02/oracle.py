"""Evaluator-owned bit-level oracle; no candidate imports or floating arithmetic."""
import hashlib, random, struct
OLD = 'dense_nk_bf16'
NEW = 'dense_k16_n_lane_bf16'
def pack(rows, baseline=False):
    n, k = len(rows), len(rows[0])
    assert 1 <= n <= 192 and k % 16 == 0
    if baseline:
        return [v for row in rows for v in row]
    # Enumeration is deliberately independent of the inverse address formula.
    return [rows[col][block + lane] for block in range(0,k,16)
            for col in range(n) for lane in range(16)]
def unpack(bits,n,k,baseline=False):
    assert len(bits)==n*k
    return [[bits[col*k+inner if baseline else ((inner//16)*n+col)*16+inner%16]
             for inner in range(k)] for col in range(n)]
def digest(bits):
    return hashlib.sha256(struct.pack('<'+'H'*len(bits),*bits)).hexdigest()
def bf16_int(v):
    if v==0:return 0
    sign=0x8000 if v<0 else 0; v=abs(v); exp=v.bit_length()-1
    assert v<=127
    return sign|((exp+127)<<7)|((v<<(7-exp))&127)
def vectors(split):
    rng=random.Random(0x02D35E if split=='public' else 0xB910C)
    shapes=[(16,1),(16,17),(64,7),(64,17),(64,191),(576,1),
            (576,17),(576,192),(1536,7),(1536,71)]
    if split=='hidden':shapes += [(16,192),(64,192),(576,191),(1536,1),(1536,31)]
    for k,n in shapes:
        rows=[[bf16_int(rng.choice([-1,1])*rng.randrange(1,128)) for _ in range(k)] for _ in range(n)]
        probes=sorted(set(i for i in [0,1,14,15,16,17,30,31,32,k-1] if i<k))
        yield {'id':f'{split}_k{k}_n{n}','k':k,'n':n,'rows':rows,'probes':probes}
def raw_bits_cases(split):
    rng=random.Random(0x102 if split=='public' else 0x8102)
    for k,n in [(16,17),(64,7),(576,191),(1536,71)]:
        # Includes zeros, subnormals, infinities and payload-bearing NaNs.
        yield k,n,[[rng.randrange(65536) for _ in range(k)] for _ in range(n)]
