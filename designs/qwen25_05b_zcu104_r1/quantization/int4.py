"""Candidate W4 format: signed symmetric group128, BF16 stored scales.

Rows are independent. Grouping and nibble packing run along the last (K)
dimension. Odd-K rows have a zero high nibble in their final byte. -8 is
reserved and is rejected by the decoder. These functions are reference
semantics, not a hardware implementation.
"""
import torch


def quantize_int4(weight, group_size=128):
    """Return int8 q[R,K] and BF16 scales[R,ceil(K/group_size)].

    s = BF16(max(abs(w))/7), q = clamp(RNE(FP32(w)/FP32(s)),-7,7).
    All-zero groups store scale 1. Underflowing scales also store 1.
    """
    if weight.ndim != 2 or group_size < 1:
        raise ValueError("Expected a matrix and positive group size")
    rows, columns = weight.shape
    if columns == 0:
        raise ValueError("K must be positive")
    w = weight.float()
    if not torch.isfinite(w).all():
        raise ValueError("Non-finite weights")
    groups = (columns + group_size - 1) // group_size
    padded = torch.nn.functional.pad(w, (0, groups * group_size - columns))
    grouped = padded.reshape(rows, groups, group_size)
    scales = (grouped.abs().amax(dim=-1) / 7).to(torch.bfloat16)
    scales = torch.where(scales == 0, torch.ones_like(scales), scales)
    q = torch.round(grouped / scales.float().unsqueeze(-1)).clamp(-7, 7)
    return q.to(torch.int8).reshape(rows, -1)[:, :columns], scales


def dequantize_int4(q, scales, group_size=128, dtype=torch.bfloat16):
    if q.ndim != 2 or group_size < 1:
        raise ValueError("Expected matrix and positive group size")
    if scales.shape != (q.shape[0], (q.shape[1] + group_size - 1) // group_size):
        raise ValueError("Scale shape mismatch")
    if ((q < -7) | (q > 7)).any():
        raise ValueError("Reserved -8 or out-of-range code")
    if not torch.isfinite(scales).all() or (scales <= 0).any():
        raise ValueError("Scales must be finite and positive")
    expanded = scales.float().repeat_interleave(group_size, dim=-1)[:, :q.shape[1]]
    return (q.float() * expanded).to(dtype)


def pack_int4(q):
    """Two's-complement nibble; even K in low nibble, odd K in high."""
    if q.ndim != 2 or ((q < -7) | (q > 7)).any():
        raise ValueError("Expected matrix with codes in [-7,7]")
    nibble = (q.to(torch.int16) & 15).to(torch.uint8)
    if q.shape[1] % 2:
        nibble = torch.nn.functional.pad(nibble, (0, 1))
    return nibble[:, 0::2] | (nibble[:, 1::2] << 4)


def unpack_int4(packed, columns):
    if packed.ndim != 2 or columns < 1 or packed.shape[1] != (columns + 1) // 2:
        raise ValueError("Packed shape mismatch")
    if packed.dtype != torch.uint8:
        raise ValueError("Packed bytes must be uint8")
    nibble = torch.stack((packed & 15, packed >> 4), dim=-1).reshape(packed.shape[0], -1)
    if columns % 2 and (nibble[:, -1] != 0).any():
        raise ValueError("Nonzero padding nibble")
    signed = torch.where(nibble >= 8, nibble.to(torch.int16) - 16, nibble.to(torch.int16))
    signed = signed[:, :columns].to(torch.int8)
    if (signed == -8).any():
        raise ValueError("Reserved -8 nibble")
    return signed
