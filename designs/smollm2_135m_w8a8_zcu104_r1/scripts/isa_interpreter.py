"""Synchronous tensor/state interpreter for the frozen binary ISA.

Concurrency is checked separately by pingpong_reference. Nonlinear functions
here are reference oracles, not selected RTL algorithms or quality evidence.
"""
import hashlib
import json
import struct
from dataclasses import dataclass
from pathlib import Path

from isa_codec import SPEC, encode, validate_command, validate_descriptor_fields
import exact_numeric as num
from integer_matrix import rows_times_rows

DESIGN = Path(__file__).resolve().parents[1]
LAYOUT = json.loads((DESIGN / "bank_layout.json").read_text())
PROFILES = SPEC["profile_encodings"]
NAMES = {v: k for k, v in PROFILES.items()}


class ExecutionError(ValueError):
    pass


def align16(value):
    return (value+15)//16*16


def pack16(values):
    return struct.pack(f"<{len(values)}H", *values)


def pack32(values):
    return struct.pack(f"<{len(values)}I", *values)


def unpack16(data):
    return list(struct.unpack(f"<{len(data)//2}H", data))


def unpack32(data):
    return list(struct.unpack(f"<{len(data)//4}I", data))


def signed(data):
    values = [v-256 if v >= 128 else v for v in data]
    if -128 in values:
        raise num.NumericError("prepared INT8 tensor contains excluded -128")
    return values


@dataclass
class Region:
    start: int
    data: bytearray
    name: str


class DDR:
    def __init__(self):
        self.regions = []

    def map(self, address, data, name="fixture"):
        if address < 0 or address+len(data) > 1 << 32:
            raise ExecutionError("DDR address range")
        if any(address < r.start+len(r.data) and r.start < address+len(data)
               for r in self.regions):
            raise ExecutionError("overlapping DDR regions")
        self.regions.append(Region(address, bytearray(data), name))

    def locate(self, address, count):
        for region in self.regions:
            if region.start <= address and address+count <= region.start+len(region.data):
                return region, address-region.start
        raise ExecutionError("unmapped DDR interval")

    def read(self, address, count):
        region, offset = self.locate(address, count)
        return bytes(region.data[offset:offset+count])

    def write(self, address, data):
        region, offset = self.locate(address, len(data))
        region.data[offset:offset+len(data)] = data


class Bank:
    def __init__(self, index):
        self.index = index
        self.info = LAYOUT["banks"][index]
        self.data = bytearray(self.info["capacity_bytes"])
        self.coverage = bytearray(len(self.data))
        self.fields = None
        self.ranges = {}
        self.generations = {0: 0, 1: 0, 2: 0}
        self.lanes = {}
        self.busy = False
        self.invalid = set()

    @property
    def name(self):
        return NAMES[self.fields["profile"]] if self.fields else None

    @property
    def generation(self):
        return max(self.generations.values())

    def configure(self, fields, internal=False):
        validate_descriptor_fields(self.index, fields)
        if self.busy and not internal:
            raise ExecutionError("configuration of busy bank")
        component = fields["component"]
        keys = [1, 2] if self.index == 7 and component == 0 else [component]
        if any(fields["generation"] <= self.generations[k] for k in keys):
            raise ExecutionError("stale descriptor generation")
        for k in keys:
            self.generations[k] = fields["generation"]
        name = NAMES[fields["profile"]]
        rows, cols = fields["rows"], fields["cols"]
        if self.index == 7:
            if component in (0, 1):
                self.fields = dict(fields)
                self.ranges["rope"] = (0, rows*128)
                self.coverage[:4096] = bytes(4096)
                self.invalid.discard("rope")
            elif self.fields is None:
                self.fields = dict(fields)
            if component in (0, 2):
                self.ranges["static"] = (4096, 6016)
                self.coverage[4096:6016] = bytes(1920)
                self.invalid.discard("static")
            return
        self.fields = dict(fields)
        self.coverage[:] = bytes(len(self.coverage))
        self.invalid.clear()
        self.lanes.clear()
        scale_length = 0
        if name in ("score_BF16", "probability_BF16", "probability_INT8"):
            data_length = rows*9*align16(cols)*(1 if name.endswith("INT8") else 2)
            if name.endswith("INT8"):
                scale_length = align16(9*((rows+15)//16)*4)
        elif name == "embedding_rows_INT8":
            data_length, scale_length = rows*cols, rows*16
        elif name == "weight_INT8":
            data_length, scale_length = rows*cols, align16(((rows+15)//16)*4)
        elif name == "A_INT8":
            data_length, scale_length = rows*cols, align16(((rows+15)//16)*4)
        elif name == "Q_INT8":
            data_length, scale_length = rows*cols, align16(9*((rows+15)//16)*4)
        elif name == "K_current_or_cache_INT8":
            data_length, scale_length = rows*cols, 16
        elif name == "V_current_or_cache_INT8":
            data_length, scale_length = rows*cols, 48
        else:
            data_length = rows*cols*2
        if data_length > self.info["payload_capacity_bytes"]:
            raise ExecutionError("profile data exceeds payload region")
        self.ranges = {"data": (0, data_length)}
        if scale_length:
            start = self.info["scale_region_byte_offset"]
            if scale_length > self.info["scale_region_capacity_bytes"]:
                raise ExecutionError("profile scale exceeds sidecar")
            self.ranges["scale"] = (start, start+scale_length)

    def write(self, offset, data, aux=0):
        end = offset+len(data)
        if not any(lo <= offset and end <= hi for lo, hi in self.ranges.values()):
            raise ExecutionError("write outside configured component")
        if aux:
            if self.name != "embedding_rows_INT8" or len(data) != 16:
                raise ExecutionError("embedding selector on wrong profile")
            row = (offset-self.info["scale_region_byte_offset"])//16
            self.lanes[row] = (aux >> 1) & 3
        elif self.name == "embedding_rows_INT8" and offset >= self.info["scale_region_byte_offset"]:
            raise ExecutionError("embedding scale block requires lane metadata")
        self.data[offset:end] = data
        self.coverage[offset:end] = b"\1"*len(data)

    def ready(self, component=None):
        keys = [component] if component else list(self.ranges)
        if not keys:
            return False
        for key in keys:
            if key not in self.ranges or key in self.invalid:
                return False
            lo, hi = self.ranges[key]
            if not all(self.coverage[lo:hi]):
                return False
        return (self.name != "embedding_rows_INT8" or
                len(self.lanes) == self.fields["rows"])

    def require(self, names, component=None):
        if self.name not in names or not self.ready(component):
            raise ExecutionError(f"bank{self.index} wrong profile or incomplete data/scale")

    def bytes(self, key="data"):
        lo, hi = self.ranges[key]
        return bytes(self.data[lo:hi])

    def snapshot(self):
        return {"profile": self.name, "generation": self.generation,
                "ready": self.ready(), "busy": self.busy,
                "components": {key: {"range": [lo, hi], "ready": self.ready(key),
                                      "sha256": hashlib.sha256(self.data[lo:hi]).hexdigest()}
                               for key, (lo, hi) in self.ranges.items()},
                "embedding_lanes": dict(self.lanes)}


class Interpreter:
    def __init__(self, ddr=None):
        self.ddr = ddr or DDR()
        self.banks = [Bank(i) for i in range(16)]
        self.command_id = 0
        self.ledger = []
        self.reference_nonlinear_used = set()

    def config(self, index, name, rows, cols, position=0, layer=0, component=0):
        generation = self.banks[index].generation+1
        return encode("BANK_CONFIG", (index, 0, 0), profile=PROFILES[name], rows=rows,
                      cols=cols, position=position, layer=layer, component=component,
                      generation=generation)

    def auto_output(self, index, name, rows, cols, data, scales=None, position=0, layer=0):
        fields = dict(profile=PROFILES[name], rows=rows, cols=cols, position=position,
                      layer=layer, component=0, generation=self.banks[index].generation+1)
        bank = self.banks[index]
        bank.configure(fields, internal=True)
        bank.write(0, data)
        if scales is not None:
            lo, hi = bank.ranges["scale"]
            packed = pack32(scales)
            bank.write(lo, packed+bytes(hi-lo-len(packed)))

    def run(self, records):
        if not 1 <= len(records) <= 16 or records[-1] != 0 or any(v == 0 for v in records[:-1]):
            raise ExecutionError("fragment requires up to15 work records then END")
        for record in records:
            self.step(record)

    def step(self, record):
        command = validate_command(record)
        op, ids, f = command["opcode"], command["banks"], command["fields"]
        used = list(next(o for o in SPEC["opcodes"] if o["opcode"] == op)["bank_positions"])
        if op == "QUANTIZE" and f["mode"] in (2, 3):
            used.append(1)
        actual = [ids[i] for i in sorted(used)]
        if any(self.banks[b].busy for b in actual):
            raise ExecutionError("bank already acquired")
        self.command_id += 1
        before = {b: self.banks[b].snapshot() for b in actual}
        accepted_generations = [self.banks[b].generation for b in actual]
        for b in actual:
            self.banks[b].busy = True
        try:
            self.execute(op, ids, f)
            status = "OK"
        except (ValueError, ArithmeticError) as error:
            destination = (ids[2] if op in ("QUANTIZE", "DEQUANTIZE", "GEMM_INT8",
                           "ATTN_SCORE_INT8", "ATTN_VALUE_INT8", "RMSNORM", "ADD", "SILU_MUL")
                           else ids[0] if op in ("DMA_LOAD", "SOFTMAX", "ROPE") else None)
            if destination is not None:
                bank = self.banks[destination]
                if op == "DMA_LOAD" and destination == 7:
                    lo, hi = f["local_byte_offset"], f["local_byte_offset"]+f["byte_count"]
                    bank.invalid.update(key for key, (start, end) in bank.ranges.items()
                                        if lo < end and start < hi)
                else:
                    bank.invalid.update(bank.ranges)
            status = f"ERROR: {error}"
        finally:
            for b in actual:
                self.banks[b].busy = False
        event = {"command_id": self.command_id, "hex128": f"{record:032x}",
                 "opcode": op, "status": status, "used_banks": actual,
                 "accepted_generations": accepted_generations,
                 "before": before, "after": {b: self.banks[b].snapshot() for b in actual},
                 "completion_scope": "synchronous response after all interpreter writes; cycle/AXI behavior checked separately"}
        self.ledger.append(event)
        if status != "OK":
            raise ExecutionError(status)
        return event

    def execute(self, op, ids, f):
        a, b, c = (self.banks[i] for i in ids)
        if op in ("END", "FENCE"):
            return
        if op == "BANK_CONFIG":
            a.configure(f, internal=True)
        elif op == "DMA_LOAD":
            a.write(f["local_byte_offset"], self.ddr.read(f["ddr_address"], f["byte_count"]), f["aux"])
        elif op == "DMA_STORE":
            lo, hi = f["local_byte_offset"], f["local_byte_offset"]+f["byte_count"]
            matches = [key for key, (start, end) in a.ranges.items() if start <= lo and hi <= end]
            if not matches or not a.ready(matches[0]) or a.index != 7 and not a.ready():
                raise ExecutionError("store from incomplete component")
            self.ddr.write(f["ddr_address"], a.data[lo:hi])
        elif op == "QUANTIZE":
            self.quantize(a, b, c, f)
        elif op == "DEQUANTIZE":
            a.require(["embedding_rows_INT8"])
            if a.fields["rows"] != f["m_count"]:
                raise ExecutionError("embedding row mismatch")
            values, scale_blocks = signed(a.bytes()), unpack32(a.bytes("scale"))
            result = [num.dequantize(value, scale_blocks[(i//576)*4+a.lanes[i//576]])
                      for i, value in enumerate(values)]
            self.auto_output(c.index, "hidden", f["m_count"], 576, pack16(result))
        elif op == "GEMM_INT8":
            a.require(["A_INT8"]); b.require(["weight_INT8"])
            if (a.fields["cols"] != f["k"] or f["m_start"]+f["m_count"] > a.fields["rows"] or
                    b.fields["cols"] != f["k"] or b.fields["rows"] != f["n_tile"] or
                    c.fields is None or c.fields["rows"] != f["m_count"] or c.fields["cols"] != f["n_total"]):
                raise ExecutionError("GEMM descriptor mismatch")
            av, bv = signed(a.bytes()), signed(b.bytes())
            sa, sb = unpack32(a.bytes("scale")), unpack32(b.bytes("scale"))
            selected = av[f["m_start"]*f["k"]:(f["m_start"]+f["m_count"])*f["k"]]
            dots = rows_times_rows(selected, bv, f["m_count"], f["n_tile"], f["k"])
            pending = []
            for row in range(f["m_count"]):
                source_row = row+f["m_start"]
                for col in range(f["n_tile"]):
                    dot = dots[row*f["n_tile"]+col]
                    result = num.scaled_output(dot, sa[source_row//16], sb[col//16])
                    pending.append(((row*f["n_total"]+f["n_start"]+col)*2, result))
            for offset, result in pending:
                c.write(offset, pack16([result]))
        elif op in ("ATTN_SCORE_INT8", "ATTN_VALUE_INT8"):
            self.attention(a, b, c, f, op == "ATTN_SCORE_INT8")
        else:
            self.reference_nonlinear_used.add(op)
            self.nonlinear(op, a, b, c, f)

    def quantize(self, a, table, output, f):
        mode, rows = f["mode"], f["m_count"]
        expected = {0: ["norm_output", "context_BF16", "SiLU_BF16"], 1: ["Q_BF16"],
                    2: ["K_BF16"], 3: ["V_BF16"], 4: ["probability_BF16"]}
        a.require(expected[mode])
        if f["m_start"]+rows > a.fields["rows"]:
            raise ExecutionError("quantization descriptor row mismatch")
        source = unpack16(a.bytes())
        groups = (rows+15)//16
        if mode == 0:
            if a.fields["cols"] != f["k"]:
                raise ExecutionError("A reduction width mismatch")
            source = source[f["m_start"]*f["k"]:(f["m_start"]+rows)*f["k"]]
            scales = [num.dynamic_scale(source[g*16*f["k"]:min(rows, (g+1)*16)*f["k"]])
                      for g in range(groups)]
            values = [num.quantize(v, scales[(i//f["k"])//16]) for i, v in enumerate(source)]
            self.auto_output(output.index, "A_INT8", rows, f["k"], bytes(v & 255 for v in values), scales)
            return
        heads = 9 if mode in (1, 4) else 3
        stride = align16(f["kv_len"]) if mode == 4 else 64
        width = heads*stride
        if mode == 4 and (a.fields["cols"] != f["kv_len"] or a.fields["position"] != f["query_start"]):
            raise ExecutionError("probability descriptor/context mismatch")
        values = [0]*(rows*width)
        scales = []
        if mode in (2, 3):
            table.require(["RoPE_and_static_KV_scales"], "static")
        for head in range(heads):
            if mode in (1, 4):
                for group in range(groups):
                    indices = [r*width+head*stride+d
                               for r in range(group*16, min(rows, (group+1)*16))
                               for d in range(stride)
                               if mode != 4 or d < f["kv_len"] and d <= f["query_start"]+r]
                    scale = num.dynamic_scale([source[i] for i in indices], mode == 4)
                    scales.append(scale)
                    for i in indices:
                        values[i] = num.quantize(source[i], scale, mode == 4)
            else:
                feature_groups = 1 if mode == 2 else 4
                for group in range(feature_groups):
                    offset = 4096+f["layer"]*64+(head*4 if mode == 2 else 16+(head*4+group)*4)
                    scale = unpack32(table.data[offset:offset+4])[0]
                    num.scale_value(scale)
                    scales.append(scale)
                    start, end = (0, 64) if mode == 2 else (group*16, (group+1)*16)
                    for row in range(rows):
                        for feature in range(start, end):
                            i = row*192+head*64+feature
                            values[i] = num.quantize(source[i], scale)
        name = {1: "Q_INT8", 2: "K_current_or_cache_INT8", 3: "V_current_or_cache_INT8",
                4: "probability_INT8"}[mode]
        self.auto_output(output.index, name, rows, f["kv_len"] if mode == 4 else heads*64,
                         bytes(v & 255 for v in values), scales,
                         position=f["query_start"] if mode == 4 else 0,
                         layer=f["layer"] if mode in (2, 3) else 0)

    def attention(self, a, b, c, f, score):
        rows, length = f["rows"], f["kv_len"]
        a.require(["Q_INT8"] if score else ["probability_INT8"])
        b.require(["K_current_or_cache_INT8"] if score else ["V_current_or_cache_INT8"])
        if a.fields["rows"] != rows or b.fields["rows"] != length:
            raise ExecutionError("attention descriptor length mismatch")
        if not score and (a.fields["cols"] != length or a.fields["position"] != f["query_start"]):
            raise ExecutionError("PV probability context mismatch")
        av, bv = signed(a.bytes()), signed(b.bytes())
        if not score and any(v < 0 for v in av):
            raise num.NumericError("negative probability encoding")
        sa, sb = unpack32(a.bytes("scale")), unpack32(b.bytes("scale"))
        groups, padded = (rows+15)//16, align16(length)
        result = [0]*(rows*9*padded if score else rows*576)
        dots_by_head = []
        for head in range(9):
            kv_head = head//3
            if score:
                left = [av[row*576+head*64+d] for row in range(rows) for d in range(64)]
                right = [bv[token*192+kv_head*64+d] for token in range(length) for d in range(64)]
                dots_by_head.append(rows_times_rows(left, right, rows, length, 64))
            else:
                left = [av[(row*9+head)*padded+t] for row in range(rows) for t in range(length)]
                right = [bv[t*192+kv_head*64+feature] for feature in range(64) for t in range(length)]
                dots_by_head.append(rows_times_rows(left, right, rows, 64, length))
        for row in range(rows):
            for head in range(9):
                kv_head = head//3
                scale_a = sa[head*groups+row//16]
                if score:
                    for token in range(min(length, f["query_start"]+row+1)):
                        dot = dots_by_head[head][row*length+token]
                        result[(row*9+head)*padded+token] = num.scaled_output(dot, scale_a, sb[kv_head], True)
                else:
                    for feature in range(64):
                        dot = dots_by_head[head][row*64+feature]
                        result[row*576+head*64+feature] = num.scaled_output(dot, scale_a,
                                                                          sb[kv_head*4+feature//16])
        self.auto_output(c.index, "score_BF16" if score else "context_BF16", rows,
                         length if score else 576, pack16(result),
                         position=f["query_start"] if score else 0)

    def nonlinear(self, op, a, b, c, f):
        if op == "SOFTMAX":
            a.require(["score_BF16"])
            rows, length = f["rows"], f["kv_len"]
            if a.fields["rows"] != rows or a.fields["cols"] != length or a.fields["position"] != f["query_start"]:
                raise ExecutionError("Softmax descriptor mismatch")
            padded = align16(length)
            source, result = unpack16(a.bytes()), [0]*(rows*9*padded)
            for row in range(rows):
                valid = min(length, f["query_start"]+row+1)
                for head in range(9):
                    base = (row*9+head)*padded
                    maximum = max(num.value16(v) for v in source[base:base+valid])
                    terms = [num.reference_exp32(num.f32(num.value16(v)-maximum))
                             for v in source[base:base+valid]]
                    total = num.f32(0)
                    for term in terms:
                        total = num.add32(total, term)
                    for token, term in enumerate(terms):
                        p = num.div32(term, total)
                        result[base+token] = num.bf16(num.value32(p))
            self.auto_output(a.index, "probability_BF16", rows, length, pack16(result), position=f["query_start"])
        elif op == "ROPE":
            a.require(["Q_BF16", "K_BF16"])
            b.require(["RoPE_and_static_KV_scales"], "rope")
            if a.fields["rows"] != f["rows"] or b.fields["rows"] != f["rows"]:
                raise ExecutionError("RoPE row mismatch")
            source, coefficient = unpack16(a.bytes()), unpack16(b.bytes("rope"))
            result, heads = list(source), a.fields["cols"]//64
            for row in range(f["rows"]):
                for head in range(heads):
                    for d in range(32):
                        index = row*heads*64+head*64+d
                        x, y = source[index], source[index+32]
                        cos, sin = coefficient[row*64+d], coefficient[row*64+32+d]
                        result[index] = num.add16(num.mul16(x, cos), num.mul16(y, sin) ^ 0x8000)
                        result[index+32] = num.add16(num.mul16(y, cos), num.mul16(x, sin))
            a.write(0, pack16(result))
        elif op == "RMSNORM":
            a.require(["hidden", "attention_residual_BF16"]); b.require(["gamma_BF16"])
            if a.fields["rows"] != f["rows"]:
                raise ExecutionError("RMS row mismatch")
            source, gamma, result = unpack16(a.bytes()), unpack16(b.bytes()), []
            for row in range(f["rows"]):
                total = num.f32(0)
                for x in source[row*576:(row+1)*576]:
                    total = num.add32(total, num.mul32(x << 16, x << 16))
                mean = num.div32(total, num.f32(576))
                inverse = num.reference_rsqrt32(num.add32(mean, num.f32(num.Fraction(1, 100000))))
                for feature, x in enumerate(source[row*576:(row+1)*576]):
                    normalized = num.mul32(x << 16, inverse)
                    cast = num.bf16(num.value32(normalized), normalized >> 31)
                    result.append(num.mul16(cast, gamma[feature]))
            self.auto_output(c.index, "norm_output", f["rows"], 576, pack16(result))
        else:
            expected = (["hidden", "attention_residual_BF16"] if op == "ADD" else ["gate_BF16"])
            a.require(expected); b.require(["projection_output"] if op == "ADD" else ["up_BF16"])
            if a.fields["rows"] != f["rows"] or b.fields["rows"] != f["rows"]:
                raise ExecutionError("vector row mismatch")
            left, right = unpack16(a.bytes()), unpack16(b.bytes())
            if op == "ADD":
                result = [num.add16(x, y) for x, y in zip(left, right)]
                name = "hidden" if c.index == 0 else "attention_residual_BF16"
            else:
                result = [num.mul16(num.reference_silu16(x), y) for x, y in zip(left, right)]
                name = "SiLU_BF16"
            self.auto_output(c.index, name, f["rows"], 576 if op == "ADD" else 1536, pack16(result))
