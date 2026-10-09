"""Numerical reference for the agreed full Attention boundaries, not an RTL PASS.

FP32 operations are unfused; probability storage rounds to BF16. Softmax exp is
an FP32 mathematical reference. A later hardware exponential approximation must
have an explicit error contract before comparing against this reference.
"""
from pathlib import Path
import sys
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'reference'))
from quantizer_reference import quantize_row


def bits(x):
    return int(np.asarray(x, dtype=np.float32).view(np.uint32))


def value(raw):
    return np.asarray(raw, dtype=np.uint32).view(np.float32)[()]


def bf16_value(raw):
    return value(int(raw) << 16)


def bf16_round(x):
    raw = bits(x)
    if (raw & 0x7f800000) == 0x7f800000:
        raise ValueError('nonfinite numerical intermediate')
    return ((raw + 0x7fff + ((raw >> 16) & 1)) >> 16) & 0xffff


def signed(nibbles):
    x = np.asarray(nibbles, dtype=np.int32)
    return np.where(x & 8, x - 16, x)


def quantize(rows):
    rows = np.asarray(rows, dtype=np.float32)
    out, scales = [], []
    for row in rows:
        result = quantize_row([bits(x) for x in row])
        if result['error']:
            raise ValueError('invalid FP32 quantizer input')
        out.append(signed(result['quantized']))
        scales.append(result['scale'])
    return np.asarray(out, dtype=np.int32), np.asarray(scales, dtype=np.uint16)


def quantize_weights(weights):
    weights = np.asarray(weights, dtype=np.float32)
    groups = (weights.shape[1] + 31) // 32
    q = np.empty(weights.shape, dtype=np.int32)
    scale = np.empty((weights.shape[0], groups), dtype=np.uint16)
    for output in range(weights.shape[0]):
        for group in range(groups):
            start, stop = 32 * group, min(32 * (group + 1), weights.shape[1])
            qrow, srow = quantize(weights[output:output+1, start:stop])
            q[output, start:stop] = qrow[0]
            scale[output, group] = srow[0]
    return q, scale


def project(a, a_scale, w, w_scale):
    a, w = np.asarray(a, dtype=np.int32), np.asarray(w, dtype=np.int32)
    if a.ndim != 2 or w.ndim != 2 or a.shape[1] != w.shape[1]:
        raise ValueError('projection shape mismatch')
    if np.any(np.abs(a) > 7) or np.any(np.abs(w) > 7):
        raise ValueError('reference uses symmetric INT4 [-7,7]')
    result = np.zeros((len(a), len(w)), dtype=np.float32)
    for token in range(len(a)):
        for output in range(len(w)):
            accumulator = np.float32(0)
            for group, start in enumerate(range(0, a.shape[1], 32)):
                partial = sum(int(x) * int(y) for x, y in
                              zip(a[token, start:start+32], w[output, start:start+32]))
                if not -(1 << 31) <= partial < (1 << 31):
                    raise OverflowError('INT32 projection partial')
                scales = np.float32(bf16_value(a_scale[token]) * bf16_value(w_scale[output, group]))
                term = np.float32(np.float32(partial) * scales)
                accumulator = np.float32(accumulator + term)
            result[token, output] = accumulator
    return result


def attention(x, wq, wk, wv, wo, heads, causal=True, valid_keys=None, query_indices=None):
    """Full projections; no bias, RoPE or model normalization implied.

    Query selection includes a decode-like last-token oracle. It recomputes
    projections here; it is not a hardware KV cache persistence implementation.
    """
    x = np.asarray(x, dtype=np.float32)
    if x.ndim != 2 or not len(x) or heads < 1:
        raise ValueError('nonempty token matrix and positive heads required')
    wq, wk, wv, wo = [np.asarray(w, dtype=np.float32) for w in (wq, wk, wv, wo)]
    width = wq.shape[0]
    if width % heads or wk.shape != wq.shape or wv.shape != wq.shape or wo.shape[1] != width:
        raise ValueError('MHA projection/head shapes mismatch')
    d = width // heads
    q_indices = list(range(len(x))) if query_indices is None else list(query_indices)
    if not q_indices or any(i < 0 or i >= len(x) for i in q_indices):
        raise ValueError('invalid query selection')
    valid_keys = np.ones(len(x), dtype=bool) if valid_keys is None else np.asarray(valid_keys, dtype=bool)
    if valid_keys.shape != (len(x),):
        raise ValueError('key mask shape mismatch')
    x4, xs = quantize(x)
    weights = [quantize_weights(w) for w in (wq, wk, wv, wo)]
    qfp, kfp, vfp = [project(x4, xs, *w) for w in weights[:3]]
    q4, qs = quantize(qfp)  # Activation: one scale per whole query token row.
    k4, ks = quantize(kfp.reshape(-1, d))  # KV: separate token/head scales.
    v4, vs = quantize(vfp.reshape(-1, d))
    q4, k4, v4 = [a.reshape(len(x), heads, d) for a in (q4, k4, v4)]
    ks, vs = [a.reshape(len(x), heads) for a in (ks, vs)]
    probability_bits = np.zeros((len(q_indices), heads, len(x)), dtype=np.uint16)
    context = np.zeros((len(q_indices), width), dtype=np.float32)
    factor = np.float32(1 / np.sqrt(np.float64(d)))
    for row, query in enumerate(q_indices):
        allowed = valid_keys & ((np.arange(len(x)) <= query) if causal else True)
        for head in range(heads):
            scores = np.zeros(len(x), dtype=np.float32)
            if not np.any(allowed):
                continue
            for key in np.flatnonzero(allowed):
                dot = sum(int(a)*int(b) for a, b in zip(q4[query, head], k4[key, head]))
                if not -(1 << 31) <= dot < (1 << 31):
                    raise OverflowError('INT32 QK sum')
                scale = np.float32(bf16_value(qs[query]) * bf16_value(ks[key, head]))
                scores[key] = np.float32(np.float32(np.float32(dot)*scale)*factor)
            maximum = np.max(scores[allowed])
            exp = np.zeros(len(x), dtype=np.float32)
            denominator = np.float32(0)
            for key in np.flatnonzero(allowed):
                exp[key] = np.float32(np.exp(np.float32(scores[key]-maximum)))
                denominator = np.float32(denominator+exp[key])
            for key in np.flatnonzero(allowed):
                probability_bits[row, head, key] = bf16_round(np.float32(exp[key]/denominator))
            for lane in range(d):
                total = np.float32(0)
                for key in np.flatnonzero(allowed):
                    v_real = np.float32(np.float32(v4[key, head, lane])*bf16_value(vs[key, head]))
                    total = np.float32(total+np.float32(bf16_value(probability_bits[row, head, key])*v_real))
                context[row, head*d+lane] = total
    context4, cs = quantize(context)
    output_fp = project(context4, cs, *weights[3])
    output4, output_scale = quantize(output_fp)
    return dict(output4=output4, output_scale=output_scale, output_fp=output_fp,
                context4=context4, context_scale=cs, probabilities_bf16=probability_bits,
                q4=q4, q_scale=qs, k4=k4, k_scale=ks, v4=v4, v_scale=vs)
