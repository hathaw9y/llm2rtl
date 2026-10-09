"""Approximation-aware Attention golden, distinct from mathematical ISA reference.

Only exp differs: finite FP32 add/mul/div and operation order otherwise agree.
This models the intended hardware and is not evidence that RTL passed.
"""
import math
from pathlib import Path
import sys
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import isa_program as isa
ref = isa.ref

EXP2_ROM = tuple(np.float32(2**(i/256)) for i in range(257))
LOG2E = ref.value(0x3fb8aa3b)

def exp_neg_bits(raw):
    x = ref.value(raw)
    if not np.isfinite(x) or x > 0:
        raise ValueError('exp requires finite nonpositive input')
    if x == 0:
        return 0x3f800000
    if x < np.float32(-80):
        return 0
    z = np.float32(x*LOG2E)
    exponent = math.floor(float(z))
    fraction = np.float32(z+np.float32(-exponent))
    index_fp = np.float32(fraction*np.float32(256))
    index = min(math.floor(float(index_fp)),255)
    blend = np.float32(index_fp+np.float32(-index))
    delta = np.float32(EXP2_ROM[index+1]-EXP2_ROM[index])
    value = np.float32(EXP2_ROM[index]+np.float32(blend*delta))
    return ref.bits(np.float32(math.ldexp(float(value),exponent)))

def attention(x,wq,wk,wv,wo,heads,causal=True,valid_keys=None,query_indices=None,exp_fn=exp_neg_bits):
    x = np.asarray(x,np.float32)
    tokens = len(x)
    width = len(wq)
    if width % heads:
        raise ValueError('head width mismatch')
    hd = width//heads
    queries = list(range(tokens)) if query_indices is None else list(query_indices)
    mask = np.ones(tokens,bool) if valid_keys is None else np.asarray(valid_keys,bool)
    if mask.shape != (tokens,):
        raise ValueError('mask mismatch')
    x4,xs = ref.quantize(x)
    weights = [ref.quantize_weights(w) for w in (wq,wk,wv,wo)]
    projections = [ref.project(x4,xs,*w) for w in weights[:3]]
    q4,qs = ref.quantize(projections[0])
    k4,ks = ref.quantize(projections[1].reshape(-1,hd))
    v4,vs = ref.quantize(projections[2].reshape(-1,hd))
    q4,k4,v4 = [a.reshape(tokens,heads,hd) for a in (q4,k4,v4)]
    ks,vs = [a.reshape(tokens,heads) for a in (ks,vs)]
    scores = np.zeros((len(queries),heads,tokens),np.float32)
    probabilities = np.zeros(scores.shape,np.uint16)
    context = np.zeros((len(queries),width),np.float32)
    factor = np.float32(1/np.sqrt(np.float64(hd)))
    for row,query in enumerate(queries):
        keys = np.flatnonzero(mask & ((np.arange(tokens)<=query) if causal else True))
        for head in range(heads):
            for key in range(tokens):
                dot = sum(int(a)*int(b) for a,b in zip(q4[query,head],k4[key,head]))
                scale = np.float32(ref.bf16_value(qs[query])*ref.bf16_value(ks[key,head]))
                scores[row,head,key] = np.float32(np.float32(np.float32(dot)*scale)*factor)
            if not len(keys):
                continue
            maximum = max(scores[row,head,key] for key in keys)
            exps = np.zeros(tokens,np.float32)
            total = np.float32(0)
            for key in keys:
                exps[key] = ref.value(exp_fn(ref.bits(np.float32(scores[row,head,key]-maximum))))
                total = np.float32(total+exps[key])
            for key in keys:
                probabilities[row,head,key] = ref.bf16_round(np.float32(exps[key]/total))
            for lane in range(hd):
                accumulator = np.float32(0)
                for key in keys:
                    v = np.float32(np.float32(v4[key,head,lane])*ref.bf16_value(vs[key,head]))
                    term = np.float32(ref.bf16_value(probabilities[row,head,key])*v)
                    accumulator = np.float32(accumulator+term)
                context[row,head*hd+lane] = accumulator
    context4,cs = ref.quantize(context)
    output_fp = ref.project(context4,cs,*weights[3])
    output4,output_scale = ref.quantize(output_fp)
    return dict(x4=x4,x_scale=xs,qfp=projections[0],kfp=projections[1],vfp=projections[2],
                q4=q4,q_scale=qs,k4=k4,k_scale=ks,v4=v4,v_scale=vs,scores=scores,
                probabilities_bf16=probabilities,context=context,context4=context4,
                context_scale=cs,output_fp=output_fp,output4=output4,output_scale=output_scale)

def pack_banks(config,result):
    mapping = {'x4':('x4','x_scale'),'qfp':('qfp',None),'kfp':('kfp',None),'vfp':('vfp',None),
               'q':('q4','q_scale'),'k':('k4','k_scale'),'v':('v4','v_scale'),
               'scores':('scores',None),'probabilities':('probabilities_bf16',None),
               'context':('context',None),'context4':('context4','context_scale'),
               'output_fp':('output_fp',None),'output4':('output4','output_scale')}
    return {d['bank']:isa.pack(d,result[mapping[d['name']][0]],
                None if mapping[d['name']][1] is None else result[mapping[d['name']][1]])
            for d in config['banks'] if d['name'] in mapping}
