"""Offline numeric model. All explicit operations are FP32, unfused, RNE.

FTZ models the selected FPGA floating-point policy; this is not PS runtime code.
"""
import torch

def f32(x):
    x = x.float() if isinstance(x, torch.Tensor) else torch.tensor(x, dtype=torch.float32)
    return torch.where(x.abs() < torch.finfo(torch.float32).tiny, x * 0.0, x)

def bf16(x):
    x = x.to(torch.bfloat16)
    return torch.where(x.abs() < torch.finfo(torch.bfloat16).tiny, x * 0.0, x)

def add(a, b): return f32(f32(a) + f32(b))
def mul(a, b): return f32(f32(a) * f32(b))

def tree16(x):
    assert x.shape[-1] == 16
    while x.shape[-1] > 1:
        x = add(x[..., 0::2], x[..., 1::2])
    return x[..., 0]

def dot(a, b):
    """a[M,K], b[N,K] -> FP32[M,N], sequential K16 reductions."""
    m, k = a.shape
    n = b.shape[0]
    padded=(k+15)//16*16
    aa=torch.nn.functional.pad(a,(0,padded-k)).reshape(m,-1,16)
    bb=torch.nn.functional.pad(b,(0,padded-k)).reshape(n,-1,16)
    # Offline vectorization of independent K16 trees, preserving every rounding.
    steps=tree16(mul(aa[:,None,:,:],bb[None,:,:,:]))
    result = torch.zeros((m, n), dtype=torch.float32)
    for block in range(steps.shape[-1]): result=add(result,steps[...,block])
    return result

def quantize(w):
    assert w.shape[-1] % 128 == 0
    rows = w.float().reshape(w.shape[0], -1, 128)
    scale = rows.abs().amax(-1) / 7.0
    scale = torch.where(scale == 0, torch.ones_like(scale), scale)
    q = torch.round(rows / scale[..., None]).clamp(-7, 7).to(torch.int8)
    return q.reshape_as(w), scale

def pack(q):
    assert q.shape[-1] % 2 == 0
    return ((q[..., 0::2].to(torch.int16) & 15) |
            ((q[..., 1::2].to(torch.int16) & 15) << 4)).to(torch.uint8)

def unpack(p):
    x = torch.stack((p & 15, p >> 4), -1).flatten(-2).to(torch.int8)
    x = torch.where(x >= 8, x-16, x)
    if (x == -8).any(): raise ValueError('reserved W4 code -8')
    return x

def dequant(q, s):
    return bf16(mul(q.reshape(q.shape[0], -1, 128), s[..., None]).reshape_as(q))

# FPGA constant tables: offline generation only. No runtime trig/exp on PS.
_i = torch.arange(257, dtype=torch.float64)
EXP2 = torch.pow(2.0, _i / 256).float()
_mid = 1.0 + (torch.arange(256, dtype=torch.float64) + .5) / 256
RECIP = (1.0 / _mid).float()
RSQRT = (1.0 / torch.sqrt(_mid)).float()

def exp_nonpositive(x):
    """Linear-interpolated 2^fraction with exact power-of-two exponent."""
    x = f32(x)
    z = mul(x, 1.4426950408889634)
    e = torch.floor(z).to(torch.int32)
    fraction = add(z, -e.float())
    t = mul(fraction, 256.0)
    index = torch.floor(t).to(torch.long).clamp(0, 255)
    delta = add(t, -index.float())
    value = add(EXP2[index], mul(delta, add(EXP2[index+1], -EXP2[index])))
    result = f32(torch.ldexp(value, e))
    return torch.where(x < -87.33654475, torch.zeros_like(result), result)

def reciprocal(x):
    mant, exponent = torch.frexp(f32(x))
    norm = mul(mant, 2.0)
    exponent = exponent - 1
    index = torch.floor(mul(add(norm, -1.0), 256.0)).long().clamp(0, 255)
    y = RECIP[index]
    for _ in range(2): y = mul(y, add(2.0, -mul(norm, y)))
    return f32(torch.ldexp(y, -exponent))

def rsqrt(x):
    mant, exponent = torch.frexp(f32(x))
    norm = mul(mant, 2.0)
    exponent = exponent - 1
    index = torch.floor(mul(add(norm, -1.0), 256.0)).long().clamp(0, 255)
    y = RSQRT[index]
    for _ in range(3):
        y = mul(mul(.5, y), add(3.0, -mul(mul(norm, y), y)))
    y = mul(y, torch.where((exponent & 1) != 0, 0.7071067811865476, 1.0))
    return f32(torch.ldexp(y, -torch.div(exponent, 2, rounding_mode='floor')))

def reduce_sum(x):
    # Same tree/serial K16 order as GEMM, with implicit zero padding.
    x = x.reshape(-1, x.shape[-1])
    total = torch.zeros(x.shape[0], dtype=torch.float32)
    for start in range(0, x.shape[-1], 16):
        tile = x[:, start:start+16]
        if tile.shape[-1] < 16:
            tile = torch.nn.functional.pad(tile, (0, 16-tile.shape[-1]))
        total = add(total, tree16(tile))
    return total

def rmsnorm(x, gamma):
    mean = mul(reduce_sum(mul(x, x)), 1.0 / x.shape[-1])
    y = bf16(mul(x, rsqrt(add(mean, 1e-6))[:, None]))
    return bf16(mul(y, gamma))

def rope(x, table, heads):
    y = x.reshape(x.shape[0], heads, 64)
    rotated = torch.cat((-y[..., 32:], y[..., :32]), -1)
    cos, sin = table[:, None, :64], table[:, None, 64:]
    return bf16(add(bf16(mul(y, cos)), bf16(mul(rotated, sin)))).reshape_as(x)

def softmax(scores, position):
    scores = bf16(mul(bf16(scores), .125)).float()
    allowed = torch.arange(scores.shape[1])[None, :] <= (position + torch.arange(scores.shape[0]))[:, None]
    masked = torch.where(allowed, scores, torch.full_like(scores, -float('inf')))
    maximum = masked.amax(-1, keepdim=True)
    # Masked entries are explicitly zero and not fed into the floating point exp.
    shifted = torch.where(allowed, add(scores, -maximum), torch.zeros_like(scores))
    values = torch.where(allowed, exp_nonpositive(shifted), torch.zeros_like(scores))
    return bf16(mul(values, reciprocal(reduce_sum(values))[:, None]))

def silu_mul(gate, up):
    e = exp_nonpositive(-gate.float().abs())
    r = reciprocal(add(1.0, e))
    sigmoid = torch.where(gate >= 0, r, mul(e, r))
    return bf16(mul(bf16(mul(gate, sigmoid)), up))
