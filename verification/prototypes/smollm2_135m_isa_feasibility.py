"""Provisional functional ISA experiment; not an RTL or BF16 bit-accuracy claim.

The program builder only uses token IDs, dimensions, layer numbers and DDR keys.
Tensor values are held by the simulated DDR and touched only by DMA/PL handlers.
"""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
import hashlib
import json
import torch
import torch.nn.functional as F
from transformers import AutoModelForCausalLM


CHECKPOINT = Path("/home/shmin/.cache/huggingface/hub/models--HuggingFaceTB--SmolLM2-135M/snapshots/93efa2f097d58c2a74874c7e644dbc9b0cee75a2")
CAPACITY = (36, 36, 36, 576, 36, 36, 12, 8, 384, 384, 576, 36, 96)
OPCODE = {name: code for code, name in enumerate((
    "END", "DMA_LOAD", "DMA_STORE", "GEMM", "RMSNORM", "ROPE",
    "ATTN_SCORE", "SOFTMAX", "ATTN_VALUE", "ADD", "SILU_MUL", "FENCE"))}
DDR_START = 0x57A00000
DDR_END = DDR_START + 512 * 1024 * 1024


@dataclass(frozen=True)
class Cmd:
    op: str
    args: tuple = ()


@dataclass
class Program:
    chunks: list[list[Cmd]] = field(default_factory=list)
    current: list[Cmd] = field(default_factory=list)

    def emit(self, op: str, *args):
        self.current.append(Cmd(op, args))

    def end(self):
        self.emit("END")
        assert len(self.current) <= 1024, len(self.current)
        self.chunks.append(self.current)
        self.current = []


def gemm_tiles(p: Program, layer: int | str, name: str, src: int, dst: int,
               out_features: int, m: int, m_start: int = 0):
    k = 1536 if name == "down_proj" else 576
    m_count = 1 if name == "lm_head" else m
    for n in range(0, out_features, 192):
        p.emit("DMA_LOAD", 3, ("weight", layer, name, n))
        p.emit("GEMM", src, 3, dst, n, out_features, m_start, m_count, k, 192)


def build_block(token_ids: list[int], start: int, final_logits: bool) -> Program:
    m = len(token_ids)
    assert 1 <= m <= 32 and start + m <= 1024
    p = Program()
    for row, token_id in enumerate(token_ids):
        p.emit("DMA_LOAD", 0, ("embedding", token_id), row, m)
    p.emit("DMA_LOAD", 7, ("rope", start, m))
    for layer in range(30):
        p.emit("DMA_LOAD", 3, ("weight", layer, "input_layernorm", 0))
        p.emit("RMSNORM", 0, 3, 2, m)
        gemm_tiles(p, layer, "q_proj", 2, 4, 576, m)
        gemm_tiles(p, layer, "k_proj", 2, 5, 192, m)
        gemm_tiles(p, layer, "v_proj", 2, 6, 192, m)
        p.emit("ROPE", 4, 7, m)
        p.emit("ROPE", 5, 7, m)
        p.emit("DMA_STORE", 5, ("kv", layer, "key", start), m)
        p.emit("DMA_STORE", 6, ("kv", layer, "value", start), m)
        p.emit("FENCE")
        p.emit("DMA_LOAD", 8, ("kv", layer, "key", start + m))
        p.emit("DMA_LOAD", 9, ("kv", layer, "value", start + m))
        p.emit("ATTN_SCORE", 4, 8, 10, start, m, start + m)
        p.emit("SOFTMAX", 10, start, m, start + m)
        p.emit("ATTN_VALUE", 10, 9, 11, start, m, start + m)
        gemm_tiles(p, layer, "o_proj", 11, 1, 576, m)
        p.emit("ADD", 0, 1, 5, m)
        p.emit("DMA_LOAD", 3, ("weight", layer, "post_attention_layernorm", 0))
        p.emit("RMSNORM", 5, 3, 2, m)
        gemm_tiles(p, layer, "gate_proj", 2, 8, 1536, m)
        gemm_tiles(p, layer, "up_proj", 2, 9, 1536, m)
        p.emit("SILU_MUL", 8, 9, 10, m)
        gemm_tiles(p, layer, "down_proj", 10, 1, 576, m)
        p.emit("ADD", 5, 1, 0, m)
        if (layer + 1) % 10 == 0:
            p.end()
    if final_logits:
        p.emit("DMA_LOAD", 3, ("weight", "final", "norm", 0))
        p.emit("RMSNORM", 0, 3, 2, m)
        gemm_tiles(p, "final", "lm_head", 2, 12, 49152, m, m - 1)
        p.emit("DMA_STORE", 12, ("logits",), 1)
        p.end()
    return p


class DDR:
    def __init__(self, model, tokens: list[int]):
        self.embedding = model.model.embed_tokens.weight.detach()
        self.rope = {}
        self.weight = {}
        self.kv = {}
        self.logits = None
        for layer, module in enumerate(model.model.layers):
            for name in ("input_layernorm", "post_attention_layernorm"):
                self.weight[layer, name, 0] = getattr(module, name).weight.detach()
            for name in ("q_proj", "k_proj", "v_proj", "o_proj",
                         "gate_proj", "up_proj", "down_proj"):
                w = getattr(module.self_attn if name in ("q_proj", "k_proj", "v_proj", "o_proj") else module.mlp, name).weight.detach()
                for n in range(0, w.shape[0], 192):
                    self.weight[layer, name, n] = w[n:n + 192].contiguous()
        self.weight["final", "norm", 0] = model.model.norm.weight.detach()
        for n in range(0, 49152, 192):
            self.weight["final", "lm_head", n] = self.embedding[n:n + 192].contiguous()
        with torch.no_grad():
            x = torch.empty((1, 1, 576), dtype=torch.bfloat16)
            pos = torch.arange(1024)[None, :]
            cos, sin = model.model.rotary_emb(x, pos)
            self.rope["cos"] = cos[0, :, :32].contiguous()
            self.rope["sin"] = sin[0, :, :32].contiguous()
        self.embedding_base = DDR_START
        cursor = self.embedding_base + self.embedding.numel() * 2
        self.weight_addr = {}
        for key, w in self.weight.items():
            if key[:2] == ("final", "lm_head"):
                self.weight_addr[key] = self.embedding_base + key[2] * 576 * 2
            else:
                self.weight_addr[key] = cursor
                cursor += w.numel() * 2
        self.rope_base = cursor
        cursor += 1024 * 32 * 2 * 2
        self.kv_base = {}
        for layer in range(30):
            for kind in ("key", "value"):
                self.kv_base[layer, kind] = cursor
                cursor += 1024 * 192 * 2
        self.logits_base = cursor
        cursor += 49152 * 2
        self.ddr_end_used = cursor
        assert cursor <= DDR_END, (hex(cursor), hex(DDR_END))

    def address_and_size(self, key, store_m=None):
        kind = key[0]
        if kind == "embedding":
            return self.embedding_base + key[1] * 1152, 1152
        if kind == "weight":
            w = self.weight[key[1:]]
            return self.weight_addr[key[1:]], w.numel() * 2
        if kind == "rope":
            _, start, m = key
            return self.rope_base + start * 128, m * 128
        if kind == "kv":
            _, layer, kv_kind, offset_or_length = key
            if store_m is None:
                return self.kv_base[layer, kv_kind], offset_or_length * 384
            return self.kv_base[layer, kv_kind] + offset_or_length * 384, store_m * 384
        if kind == "logits":
            return self.logits_base, 49152 * 2
        raise ValueError(key)

    def read(self, key):
        kind = key[0]
        if kind == "embedding":
            return self.embedding[key[1]].clone()
        if kind == "weight":
            return self.weight[key[1:]].clone()
        if kind == "rope":
            _, start, m = key
            return (self.rope["cos"][start:start + m].clone(),
                    self.rope["sin"][start:start + m].clone())
        if kind == "kv":
            _, layer, kv_kind, length = key
            x = self.kv[layer, kv_kind]
            assert x.shape[0] == length
            return x.reshape(length, 192).clone()
        raise ValueError(key)


class Machine:
    def __init__(self, ddr: DDR, gemm_mode="torch_bf16_reference"):
        self.ddr = ddr
        self.gemm_mode = gemm_mode
        self.bank = [None] * 13
        self.valid = [False] * 13
        self.progress = {}
        self.executed = Counter()
        self.chunks = 0
        self.stores_since_fence = 0
        self.samples = {}
        self.oracle = None
        self.oracle_checks = Counter()
        self.active_weight_key = None
        self.current_layer = None
        self.add_phase = Counter()

    def put(self, idx, value):
        size = sum(x.numel() * x.element_size() for x in value) if isinstance(value, tuple) else value.numel() * value.element_size()
        assert size <= CAPACITY[idx] * 1024, (idx, size, CAPACITY[idx])
        self.bank[idx] = value
        self.valid[idx] = True

    def get(self, idx):
        assert self.valid[idx], f"bank {idx} not valid"
        return self.bank[idx]

    def run(self, program):
        for chunk in program.chunks:
            assert chunk[-1].op == "END" and len(chunk) <= 1024
            for cmd in chunk:
                record = wire_record(cmd, self.ddr)
                decoded = wire_decode(record, self.ddr)
                assert decoded == cmd, (decoded, cmd)
                sample_name = sample_key(decoded)
                before = self.snapshot(decoded) if sample_name not in self.samples else None
                self.execute(decoded)
                self.check_oracle(decoded)
                if before is not None:
                    self.samples[sample_name] = {"record_hex": f"{record:032x}",
                                                 "before": before,
                                                 "after": self.snapshot(decoded)}
            self.chunks += 1
        return self.get(12) if self.valid[12] else None

    def execute(self, cmd):
        op, a = cmd.op, cmd.args
        self.executed[op] += 1
        if op == "END":
            return
        if op == "DMA_LOAD":
            dst, key, *partial = a
            if key[0] == "weight":
                self.active_weight_key = key[1:]
                if key[2] == "input_layernorm":
                    self.current_layer = key[1]
            if partial:
                row, m = partial
                assert key[0] == "embedding"
                if row == 0:
                    self.bank[dst] = torch.empty((m, 576), dtype=torch.bfloat16)
                    self.valid[dst] = False
                assert row == self.progress.get(dst, 0)
                self.bank[dst][row] = self.ddr.read(key)
                self.progress[dst] = row + 1
                if row + 1 == m:
                    self.valid[dst] = True
                    self.progress[dst] = 0
            else:
                self.put(dst, self.ddr.read(key))
        elif op == "RMSNORM":
            src, gamma, dst, rows = a
            x = self.get(src).float()
            assert x.shape == (rows, 576)
            y = x * torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + 1e-5)
            self.put(dst, self.get(gamma) * y.to(torch.bfloat16))
        elif op == "GEMM":
            src, weight, dst, n, n_total, m_start, m_count, k, n_tile = a
            x = self.get(src)[m_start:m_start + m_count]
            assert x.shape == (m_count, k) and self.get(weight).shape == (n_tile, k)
            if self.gemm_mode == "fp32_accumulate_bf16_round":
                y = F.linear(x.float(), self.get(weight).float()).to(torch.bfloat16)
            else:
                assert self.gemm_mode == "torch_bf16_reference"
                y = F.linear(x, self.get(weight))
            if n == 0:
                self.bank[dst] = torch.empty((x.shape[0], n_total), dtype=torch.bfloat16)
                self.valid[dst] = False
                self.progress[dst] = 0
            assert n == self.progress[dst]
            self.bank[dst][:, n:n + y.shape[1]] = y
            self.progress[dst] += y.shape[1]
            if self.progress[dst] == n_total:
                self.valid[dst] = True
        elif op == "ROPE":
            idx, coeff, rows = a
            x = self.get(idx)
            assert x.shape[0] == rows
            cos_half, sin_half = self.get(coeff)
            cos = torch.cat((cos_half, cos_half), -1)[:, None, :]
            sin = torch.cat((sin_half, sin_half), -1)[:, None, :]
            h = x.shape[-1] // 64
            v = x.reshape(x.shape[0], h, 64)
            half = torch.cat((-v[..., 32:], v[..., :32]), -1)
            self.put(idx, ((v * cos) + (half * sin)).reshape(x.shape))
        elif op == "DMA_STORE":
            src, key, m = a
            if key[0] == "logits":
                assert m == 1 and self.get(src).shape == (1, 49152)
                self.ddr.logits = self.get(src).clone()
                self.stores_since_fence += 1
                return
            _, layer, kind, start = key
            x = self.get(src).reshape(-1, 3, 64).clone()
            assert x.shape[0] == m
            kv_key = (layer, kind)
            if start == 0:
                self.ddr.kv[kv_key] = x
            else:
                assert self.ddr.kv[kv_key].shape[0] == start
                self.ddr.kv[kv_key] = torch.cat((self.ddr.kv[kv_key], x), 0)
            self.stores_since_fence += 1
        elif op == "FENCE":
            assert self.stores_since_fence > 0
            self.stores_since_fence = 0
        elif op == "ATTN_SCORE":
            q_bank, k_bank, dst, start, m, kv_len = a
            q = self.get(q_bank).reshape(-1, 9, 64).transpose(0, 1)
            k = self.get(k_bank).reshape(-1, 3, 64).transpose(0, 1).repeat_interleave(3, 0)
            assert q.shape[1] == m and k.shape[1] == kv_len
            score = torch.matmul(q, k.transpose(1, 2)) * 0.125
            pos = torch.arange(start, start + q.shape[1])
            mask = torch.arange(k.shape[1])[None, :] > pos[:, None]
            score = score + mask[None, :, :].to(torch.bfloat16) * torch.finfo(torch.bfloat16).min
            self.put(dst, score)
        elif op == "SOFTMAX":
            idx, query_start, m_count, kv_len = a
            score = self.get(idx)
            assert score.shape == (9, m_count, kv_len)
            assert query_start + m_count <= kv_len
            self.put(idx, F.softmax(score, dim=-1, dtype=torch.float32).to(torch.bfloat16))
        elif op == "ATTN_VALUE":
            prob_bank, v_bank, dst, start, m, kv_len = a
            prob = self.get(prob_bank)
            v = self.get(v_bank).reshape(-1, 3, 64).transpose(0, 1).repeat_interleave(3, 0)
            assert prob.shape == (9, m, kv_len) and v.shape[1] == kv_len
            assert start + m <= kv_len
            y = torch.matmul(prob, v).transpose(0, 1).contiguous().reshape(prob.shape[1], 576)
            self.put(dst, y)
        elif op == "ADD":
            x, y, dst, rows = a
            assert self.get(x).shape[0] == rows and self.get(y).shape[0] == rows
            self.put(dst, self.get(x) + self.get(y))
        elif op == "SILU_MUL":
            x, y, dst, rows = a
            assert self.get(x).shape == self.get(y).shape == (rows, 1536)
            self.put(dst, F.silu(self.get(x)) * self.get(y))
        else:
            raise ValueError(op)

    def check_oracle(self, cmd):
        if self.oracle is None:
            return
        op, a = cmd.op, cmd.args
        captured = self.oracle["captured"]
        layer = self.current_layer
        name = None
        actual = None
        expected = None
        if op == "RMSNORM":
            layer_id, weight_name, _ = self.active_weight_key
            name = f"RMSNORM_{weight_name}"
            actual = self.get(a[2])
            expected = captured[layer_id, weight_name][0]
        elif op == "GEMM" and a[3] + a[8] == a[4]:
            layer_id, weight_name, _ = self.active_weight_key
            name = f"GEMM_{weight_name}"
            actual = self.get(a[2])
            expected = captured[layer_id, weight_name][0]
        elif op == "ROPE" and a[0] == 5:
            name = "ROPE_key"
            actual = self.get(5).reshape(-1, 3, 64).transpose(0, 1)
            start, m = self.oracle["start"], self.oracle["m"]
            expected = self.oracle["cache"].layers[layer].keys[0, :, start:start + m]
        elif op == "SOFTMAX":
            name = "SOFTMAX"
            actual = self.get(10)
            expected = captured[layer, "attn_weights"][0]
        elif op == "ATTN_VALUE":
            name = "ATTN_VALUE"
            actual = self.get(11)
            expected = captured[layer, "o_proj_input"][0]
        elif op == "SILU_MUL":
            name = "SILU_MUL"
            actual = self.get(10)
            expected = captured[layer, "down_proj_input"][0]
        elif op == "ADD":
            phase = self.add_phase[layer] % 2
            self.add_phase[layer] += 1
            name = "ADD_attention" if phase == 0 else "ADD_ffn"
            actual = self.get(a[2])
            expected = captured[layer, "post_attention_layernorm_input"][0] if phase == 0 else captured[layer, "layer_output"][0]
        if actual is not None:
            assert actual.shape == expected.shape and torch.equal(actual, expected), (name, layer, compare(name, actual, expected))
            self.oracle_checks[name] += 1

    def snapshot(self, cmd):
        a = cmd.args
        if cmd.op in ("DMA_LOAD", "DMA_STORE", "SOFTMAX"):
            ids = a[:1]
        elif cmd.op == "ROPE":
            ids = a[:2]
        elif cmd.op in ("GEMM", "RMSNORM", "ATTN_SCORE", "ATTN_VALUE", "ADD", "SILU_MUL"):
            ids = a[:3]
        else:
            ids = ()
        return {"banks": {str(i): {"valid": self.valid[i],
                                   "progress": self.progress.get(i, 0),
                                   "value": tensor_sample(self.bank[i]) if self.valid[i] else None}
                          for i in ids},
                "ddr_kv_layer0": {kind: tensor_sample(self.ddr.kv[0, kind])
                                  for kind in ("key", "value") if (0, kind) in self.ddr.kv}
                if cmd.op in ("DMA_STORE", "FENCE") else {},
                "stores_since_fence": self.stores_since_fence}


def tensor_sample(value):
    if isinstance(value, tuple):
        return [tensor_sample(x) for x in value]
    if value is None:
        return None
    raw = value.contiguous().view(torch.uint16).numpy().tobytes()
    return {"shape": list(value.shape), "dtype": str(value.dtype),
            "sha256": hashlib.sha256(raw).hexdigest(),
            "first_bf16_hex": [f"{int(x):04x}" for x in value.reshape(-1)[:8].view(torch.uint16)]}


def sample_key(cmd):
    if cmd.op == "DMA_LOAD":
        kind = cmd.args[1][0]
        if kind == "embedding":
            return "DMA_LOAD_embedding_complete" if cmd.args[2] + 1 == cmd.args[3] else "DMA_LOAD_embedding_partial"
        return f"DMA_LOAD_{kind}"
    if cmd.op == "GEMM":
        n, n_total = cmd.args[3:5]
        return "GEMM_last_tile" if n + 192 == n_total else "GEMM_first_tile" if n == 0 else "GEMM_middle_tile"
    if cmd.op == "DMA_STORE":
        return f"DMA_STORE_{cmd.args[1][0]}"
    return cmd.op


def wire_record(cmd: Cmd, ddr: DDR) -> int:
    """Check one candidate 128-bit record against template field widths."""
    op, a = cmd.op, cmd.args
    banks = [0, 0, 0]
    payload = 0
    if op in ("DMA_LOAD", "DMA_STORE"):
        banks[0] = a[0]
        key = a[1]
        if op == "DMA_LOAD":
            address, byte_count = ddr.address_and_size(key)
        else:
            assert key[0] in ("kv", "logits")
            address, byte_count = ddr.address_and_size(key, store_m=a[2])
        local_offset = 0
        reserved = 0
        if op == "DMA_LOAD" and len(a) == 4:
            row, expected_rows = a[2:]
            local_offset = row * 1152
            reserved = (expected_rows << 6) | row
        assert DDR_START <= address and address + byte_count <= DDR_END
        assert 0 < byte_count < (1 << 23)
        assert local_offset < (1 << 32) and reserved < (1 << 25)
        payload = (local_offset << 80) | (byte_count << 57) | (address << 25) | reserved
    elif op == "GEMM":
        src, weight, dst, n, n_total, m_start, m_count, k, n_tile = a
        banks = [src, weight, dst]
        widths = (16, 16, 6, 6, 11, 8)
        for value, width in zip((n, n_total, m_start, m_count, k, n_tile), widths):
            assert 0 <= value < (1 << width), (op, value, width)
            payload = (payload << width) | value
    elif op in ("ATTN_SCORE", "ATTN_VALUE"):
        banks = list(a[:3])
        _, _, _, q_start, m_count, kv_len = a
        for value, width in ((q_start, 10), (m_count, 6), (kv_len, 11)):
            assert 0 <= value < (1 << width)
            payload = (payload << width) | value
    elif op == "RMSNORM":
        banks = list(a[:3])
        rows = a[3]
        assert 1 <= rows <= 32
        payload = rows
    elif op == "ADD":
        banks = list(a[:3])
        rows = a[3]
        assert 1 <= rows <= 32
        payload = rows
    elif op == "SILU_MUL":
        banks = list(a[:3])
        rows = a[3]
        assert 1 <= rows <= 32
        payload = rows
    elif op == "ROPE":
        banks[:2] = a[:2]
        rows = a[2]
        assert 1 <= rows <= 32
        payload = rows
    elif op == "SOFTMAX":
        banks[0] = a[0]
        _, q_start, m_count, kv_len = a
        for value, width in ((q_start, 10), (m_count, 6), (kv_len, 11)):
            assert 0 <= value < (1 << width)
            payload = (payload << width) | value
    elif op not in ("FENCE", "END"):
        raise ValueError(op)
    assert all(0 <= bank < 16 for bank in banks)
    assert 0 <= payload < (1 << 112)
    record = (OPCODE[op] << 124) | (banks[0] << 120) | (banks[1] << 116) | (banks[2] << 112) | payload
    assert record < (1 << 128)
    assert record >> 124 == OPCODE[op]
    return record


def wire_decode(record: int, ddr: DDR) -> Cmd:
    """Decode the packed record used by the interpreter, including DDR addresses."""
    op = tuple(OPCODE)[record >> 124]
    b = ((record >> 120) & 15, (record >> 116) & 15, (record >> 112) & 15)
    payload = record & ((1 << 112) - 1)
    if op in ("DMA_LOAD", "DMA_STORE"):
        offset = payload >> 80
        count = (payload >> 57) & ((1 << 23) - 1)
        address = (payload >> 25) & ((1 << 32) - 1)
        reserved = payload & ((1 << 25) - 1)
        for key, addr in ddr.weight_addr.items():
            if addr == address and ddr.weight[key].numel() * 2 == count:
                assert op == "DMA_LOAD" and offset == reserved == 0
                return Cmd(op, (b[0], ("weight", *key)))
        if ddr.embedding_base <= address < ddr.embedding_base + ddr.embedding.numel() * 2:
            assert op == "DMA_LOAD" and count == 1152
            token_id, rem = divmod(address - ddr.embedding_base, 1152)
            assert rem == 0
            row, m = reserved & 63, reserved >> 6
            assert offset == row * 1152 and 0 < m <= 32 and row < m
            return Cmd(op, (b[0], ("embedding", token_id), row, m))
        if ddr.rope_base <= address < ddr.rope_base + 1024 * 128:
            assert op == "DMA_LOAD" and offset == reserved == 0
            start, rem = divmod(address - ddr.rope_base, 128)
            assert rem == 0 and count % 128 == 0
            return Cmd(op, (b[0], ("rope", start, count // 128)))
        if address == ddr.logits_base:
            assert op == "DMA_STORE" and offset == reserved == 0 and count == 49152 * 2
            return Cmd(op, (b[0], ("logits",), 1))
        for (layer, kind), base in ddr.kv_base.items():
            if base <= address < base + 1024 * 384:
                assert offset == reserved == 0 and count % 384 == 0
                pos, rem = divmod(address - base, 384)
                assert rem == 0
                if op == "DMA_LOAD":
                    assert pos == 0
                    return Cmd(op, (b[0], ("kv", layer, kind, count // 384)))
                return Cmd(op, (b[0], ("kv", layer, kind, pos), count // 384))
        raise AssertionError((op, hex(address), count))
    if op == "GEMM":
        values = []
        for width in (8, 11, 6, 6, 16, 16):
            values.append(payload & ((1 << width) - 1))
            payload >>= width
        n_tile, k, m_count, m_start, n_total, n = values
        assert payload == 0
        return Cmd(op, (*b, n, n_total, m_start, m_count, k, n_tile))
    if op in ("ATTN_SCORE", "ATTN_VALUE"):
        kv_len = payload & ((1 << 11) - 1)
        m_count = (payload >> 11) & 63
        start = (payload >> 17) & 1023
        assert payload >> 27 == 0
        return Cmd(op, (*b, start, m_count, kv_len))
    if op == "RMSNORM":
        assert 1 <= payload <= 32
        return Cmd(op, (*b, payload))
    if op == "ADD":
        assert 1 <= payload <= 32
        return Cmd(op, (*b, payload))
    if op == "SILU_MUL":
        assert 1 <= payload <= 32
        return Cmd(op, (*b, payload))
    if op == "ROPE":
        assert b[2] == 0 and 1 <= payload <= 32
        return Cmd(op, (*b[:2], payload))
    if op == "SOFTMAX":
        assert b[1:] == (0, 0) and payload >> 27 == 0
        kv_len = payload & ((1 << 11) - 1)
        m_count = (payload >> 11) & 63
        start = (payload >> 17) & 1023
        return Cmd(op, (b[0], start, m_count, kv_len))
    assert op in ("FENCE", "END") and payload == 0
    return Cmd(op)


def compare(name, actual, reference):
    a, b = actual.float(), reference.float()
    return {"name": name, "shape": list(a.shape), "max_abs": float((a - b).abs().max()),
            "mean_abs": float((a - b).abs().mean()), "exact": bool(torch.equal(actual, reference))}


def install_reference_hooks(model, captured):
    handles = []

    def output_hook(key, tuple_index=None):
        def hook(_module, _args, output):
            value = output[tuple_index] if tuple_index is not None else output
            captured[key] = value.detach().clone()
        return hook

    def input_hook(key):
        def hook(_module, args):
            captured[key] = args[0].detach().clone()
        return hook

    for layer, module in enumerate(model.model.layers):
        for name in ("input_layernorm", "post_attention_layernorm"):
            node = getattr(module, name)
            handles.append(node.register_forward_hook(output_hook((layer, name))))
        handles.append(module.post_attention_layernorm.register_forward_pre_hook(
            input_hook((layer, "post_attention_layernorm_input"))))
        for container, names in ((module.self_attn, ("q_proj", "k_proj", "v_proj", "o_proj")),
                                 (module.mlp, ("gate_proj", "up_proj", "down_proj"))):
            for name in names:
                handles.append(getattr(container, name).register_forward_hook(output_hook((layer, name))))
        handles.append(module.self_attn.o_proj.register_forward_pre_hook(input_hook((layer, "o_proj_input"))))
        handles.append(module.mlp.down_proj.register_forward_pre_hook(input_hook((layer, "down_proj_input"))))
        handles.append(module.self_attn.register_forward_hook(output_hook((layer, "attn_weights"), 1)))
        handles.append(module.register_forward_hook(output_hook((layer, "layer_output"))))
    handles.append(model.model.norm.register_forward_hook(output_hook(("final", "norm"))))
    handles.append(model.lm_head.register_forward_hook(output_hook(("final", "lm_head"))))
    return handles


def main():
    torch.set_num_threads(4)
    model = AutoModelForCausalLM.from_pretrained(
        str(CHECKPOINT), local_files_only=True, dtype=torch.bfloat16,
        attn_implementation="eager").eval()
    tokens = [(i * 17 + 11) % 49152 for i in range(64)]
    ddr = DDR(model, tokens)
    results = []
    case_stats = []
    command_samples = {}
    captured = {}
    handles = install_reference_hooks(model, captured)
    boundary = build_block(tokens[:32], 992, True)
    boundary_records = [wire_record(cmd, ddr) for chunk in boundary.chunks for cmd in chunk]
    with torch.inference_mode():
        for case_name, sizes in (("prefill32_decode1", (32, 1)),
                                 ("prefill32_prefill32", (32, 32))):
            ddr.kv.clear()
            machine = Machine(ddr)
            cache = None
            start = 0
            max_chunk = 0
            for m in sizes:
                ids = tokens[start:start + m]
                captured.clear()
                reference = model(torch.tensor([ids]), past_key_values=cache,
                                  use_cache=True, logits_to_keep=1)
                cache = reference.past_key_values
                machine.oracle = {"captured": captured, "cache": cache,
                                  "start": start, "m": m}
                program = build_block(ids, start, final_logits=True)
                max_chunk = max(max_chunk, *(len(c) for c in program.chunks))
                for chunk in program.chunks:
                    for cmd in chunk:
                        wire_record(cmd, ddr)
                actual = machine.run(program)
                result = compare(f"{case_name}_logits_{start + m}", actual, reference.logits[0])
                assert result["exact"], result
                assert torch.equal(ddr.logits, reference.logits[0])
                results.append(result)
                for layer in range(30):
                    for kind, attr in (("key", "keys"), ("value", "values")):
                        a = ddr.kv[layer, kind].transpose(0, 1)
                        b = getattr(cache.layers[layer], attr)[0]
                        assert torch.equal(a, b), (case_name, layer, kind, start + m)
                start += m
            case_stats.append({"case": case_name, "chunks": machine.chunks,
                               "max_chunk_records": max_chunk,
                               "commands": dict(machine.executed),
                               "reference_internal_checks": dict(machine.oracle_checks),
                               "kv_layers_exact": 30})
            if not command_samples:
                command_samples = machine.samples
        ddr.kv.clear()
        rounded_machine = Machine(ddr, gemm_mode="fp32_accumulate_bf16_round")
        rounded_cache = None
        rounded_comparison = []
        for start, m in ((0, 32), (32, 1)):
            ids = tokens[start:start + m]
            rounded_logits = rounded_machine.run(build_block(ids, start, True))
            rounded_ref = model(torch.tensor([ids]), past_key_values=rounded_cache,
                                use_cache=True, logits_to_keep=1)
            rounded_cache = rounded_ref.past_key_values
            result = compare(f"fp32_accumulate_bf16_round_logits_{start + m}",
                             rounded_logits, rounded_ref.logits[0])
            ref_top = torch.topk(rounded_ref.logits[0].float().reshape(-1), 2)
            trial_top = torch.topk(rounded_logits.float().reshape(-1), 2)
            result["top1_equal"] = bool(torch.argmax(rounded_logits) == torch.argmax(rounded_ref.logits[0]))
            result["reference_top1_id"] = int(torch.argmax(rounded_ref.logits[0]))
            result["candidate_top1_id"] = int(torch.argmax(rounded_logits))
            result["reference_top1_margin"] = float(ref_top.values[0] - ref_top.values[1])
            result["candidate_top1_margin"] = float(trial_top.values[0] - trial_top.values[1])
            result["candidate_max_tie_count"] = int((rounded_logits == rounded_logits.max()).sum())
            result["reference_top1_value"] = float(ref_top.values[0])
            result["candidate_top1_value"] = float(trial_top.values[0])
            result["different_elements"] = int((rounded_logits != rounded_ref.logits[0]).sum())
            rounded_comparison.append(result)
    print(json.dumps({"comparison": results, "cases": case_stats,
                      "command_samples": command_samples,
                      "fp32_accumulation_experiment": rounded_comparison,
                      "boundary_1024_wire_records": len(boundary_records),
                      "boundary_1024_max_chunk_records": max(map(len, boundary.chunks)),
                      "ddr_bytes_used": ddr.ddr_end_used - DDR_START,
                      "bank_capacity_kib": list(CAPACITY)}, indent=2))
    for handle in handles:
        handle.remove()


if __name__ == "__main__":
    main()
