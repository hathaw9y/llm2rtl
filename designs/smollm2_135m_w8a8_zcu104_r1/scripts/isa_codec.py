"""128-bit codec for the frozen W8A8 ISA; no tensor execution."""
import json
from pathlib import Path

DESIGN = Path(__file__).resolve().parents[1]
SPEC = json.loads((DESIGN / "isa_spec.json").read_text())
OPCODES = {op["opcode"]: op for op in SPEC["opcodes"]}
BY_CODE = {op["encoding"]: op for op in SPEC["opcodes"]}
FORMATS = SPEC["instruction_record"]["payload_formats"]


def uint(value, width, name):
    if type(value) is not int or not 0 <= value < 1 << width:
        raise ValueError(f"{name} must be an unsigned {width}-bit integer")
    return value


def validate_banks(op, banks, fields):
    used = list(op["bank_positions"])
    if op["opcode"] == "QUANTIZE" and fields.get("mode", 0) in (2, 3):
        used.append(1)
    for position, bank in enumerate(banks):
        uint(bank, 4, f"bank{position}")
        if position not in used and bank != 0:
            raise ValueError("unused bank fields must be zero")
    if len({banks[i] for i in used}) != len(used):
        raise ValueError("operand banks must be distinct; in-place ops use one role")


def encode(opcode, banks=(0, 0, 0), **fields):
    if opcode not in OPCODES or len(banks) != 3:
        raise ValueError("unknown opcode or wrong bank field count")
    op = OPCODES[opcode]
    layout = FORMATS[op["payload_format"]]
    if fields.keys() - layout.keys():
        raise ValueError("unknown payload field")
    validate_banks(op, banks, fields)
    record = op["encoding"] << 124
    for position, bank in enumerate(banks):
        record |= bank << (120 - position*4)
    for name, (high, low) in layout.items():
        record |= uint(fields.get(name, 0), high-low+1, name) << low
    return record


def decode(record):
    uint(record, 128, "record")
    code = record >> 124
    if code not in BY_CODE:
        raise ValueError("reserved opcode")
    op = BY_CODE[code]
    layout = FORMATS[op["payload_format"]]
    mask = 0
    fields = {}
    for name, (high, low) in layout.items():
        field_mask = ((1 << (high-low+1))-1) << low
        mask |= field_mask
        fields[name] = (record & field_mask) >> low
    if record & (((1 << 112)-1) ^ mask):
        raise ValueError("reserved payload bits must be zero")
    banks = tuple((record >> shift) & 15 for shift in (120, 116, 112))
    validate_banks(op, banks, fields)
    return {"opcode": op["opcode"], "banks": banks, "fields": fields}


def words(record):
    uint(record, 128, "record")
    return tuple((record >> (i*32)) & 0xffffffff for i in range(4))


def from_words(values):
    if len(values) != 4:
        raise ValueError("four PS words required")
    return sum(uint(v, 32, "PS word") << (i*32) for i, v in enumerate(values))


def validate_descriptor_fields(bank, fields):
    """Shape/profile checks before BANK_CONFIG may mutate a descriptor."""
    layout = json.loads((DESIGN / "bank_layout.json").read_text())
    desc = layout["banks"][bank]
    profile = fields["profile"]
    if profile not in desc["profile_codes"] or fields["generation"] == 0:
        raise ValueError("illegal profile or zero generation")
    component = fields["component"]
    if component not in ((0, 1, 2) if bank == 7 else (0,)):
        raise ValueError("illegal component update")
    rows, cols = fields["rows"], fields["cols"]
    name = next(n for n, code in SPEC["profile_encodings"].items() if code == profile)
    if name == "weight_INT8":
        valid = 1 <= rows <= 192 and cols in (576, 1536)
    elif name == "gamma_BF16":
        valid = rows == 1 and cols == 576
    elif name == "RoPE_and_static_KV_scales":
        valid = (rows == 30 and cols == 64 if component == 2
                 else 1 <= rows <= 32 and cols == 64 and fields["position"]+rows <= 1024)
    elif name in ("K_current_or_cache_INT8", "V_current_or_cache_INT8"):
        valid = 1 <= rows <= 1024 and cols == 192 and fields["layer"] < 30
    elif name in ("score_BF16", "probability_BF16", "probability_INT8"):
        valid = 1 <= rows <= 32 and 1 <= cols <= 1024 and fields["position"]+rows <= cols
    elif name == "A_INT8":
        valid = 1 <= rows <= 32 and cols in (576, 1536)
    elif name == "last_token_logits":
        valid = rows == 1 and cols == 49152
    else:
        width = (192 if name in ("K_BF16", "V_BF16") else
                 1536 if name in ("gate_BF16", "up_BF16", "SiLU_BF16") else 576)
        valid = 1 <= rows <= 32 and cols == width
    if not valid:
        raise ValueError("illegal descriptor shape")
    if name not in ("RoPE_and_static_KV_scales", "score_BF16",
                    "probability_BF16", "probability_INT8") and fields["position"]:
        raise ValueError("unused position must be zero")
    if name not in ("K_current_or_cache_INT8", "V_current_or_cache_INT8") and fields["layer"]:
        raise ValueError("unused layer must be zero")


def validate_command(record):
    """Static checks only; runtime generation/coverage/ownership are external."""
    command = decode(record)
    op, banks, f = command["opcode"], command["banks"], command["fields"]
    if op in ("DMA_LOAD", "DMA_STORE"):
        count, address, offset = f["byte_count"], f["ddr_address"], f["local_byte_offset"]
        if not count or (count | address | offset) & 15 or address+count > 1 << 32:
            raise ValueError("bad DMA length/alignment/address range")
        layout = json.loads((DESIGN / "bank_layout.json").read_text())
        if offset+count > layout["banks"][banks[0]]["capacity_bytes"]:
            raise ValueError("DMA exceeds bank allocation")
        if f["aux"]:
            if (op != "DMA_LOAD" or banks[0] != 3 or f["aux"] & ~7 or
                    not f["aux"] & 1 or count != 16 or not 294912 <= offset < 295424):
                raise ValueError("illegal embedding scale lane selector")
    elif op == "BANK_CONFIG":
        validate_descriptor_fields(banks[0], f)
    elif op == "GEMM_INT8":
        if (banks[0] != 13 or banks[1] not in (3, 15) or
                not 1 <= f["m_count"] <= 32 or f["m_start"]+f["m_count"] > 32 or
                f["k"] not in (576, 1536) or not 1 <= f["n_tile"] <= 192 or
                not 1 <= f["n_total"] <= 49152 or f["n_start"] % 64 or
                f["n_start"]+f["n_tile"] > f["n_total"]):
            raise ValueError("bad GEMM shape or operands")
        layout = json.loads((DESIGN / "bank_layout.json").read_text())
        allowed = {1: 576, 4: 576, 5: 192, 6: 192, 8: 1536, 9: 1536, 12: 49152}
        if banks[2] not in allowed or f["n_total"] != allowed[banks[2]]:
            raise ValueError("wrong projection output profile")
        if f["m_count"]*f["n_total"]*2 > layout["banks"][banks[2]]["payload_capacity_bytes"]:
            raise ValueError("GEMM output exceeds capacity")
    elif op in ("ATTN_SCORE_INT8", "ATTN_VALUE_INT8", "SOFTMAX"):
        if (not 1 <= f["rows"] <= 32 or not 1 <= f["kv_len"] <= 1024 or
                f["query_start"]+f["rows"] > f["kv_len"]):
            raise ValueError("bad attention shape")
        expected = {"ATTN_SCORE_INT8": (14, 8, 10),
                    "ATTN_VALUE_INT8": (13, 9, 11), "SOFTMAX": (10, 0, 0)}
        if banks != expected[op]:
            raise ValueError("wrong attention banks")
    elif op in ("RMSNORM", "ROPE", "ADD", "SILU_MUL"):
        if not 1 <= f["rows"] <= 32:
            raise ValueError("bad row count")
        if op == "ROPE" and (banks[0] not in (4, 5) or banks[1] != 7):
            raise ValueError("wrong RoPE banks")
        if list(banks) not in SPEC["fixed_routes"][op]:
            raise ValueError("wrong nonlinear/vector banks")
    elif op in ("QUANTIZE", "DEQUANTIZE"):
        mode = f["mode"]
        if not 1 <= f["m_count"] <= 32 or f["m_start"]+f["m_count"] > 32:
            raise ValueError("bad quantization rows")
        if op == "DEQUANTIZE":
            if (banks != (3, 0, 0) or mode != 0 or f["k"] != 576 or
                    any(f[n] for n in ("m_start", "kv_len", "query_start", "layer"))):
                raise ValueError("bad embedding dequantization")
        elif mode == 0:
            if (banks[0] not in (2, 10, 11) or banks[2] != 13 or
                    f["k"] not in (576, 1536) or
                    any(f[n] for n in ("kv_len", "query_start", "layer"))):
                raise ValueError("bad A quantization")
        elif mode in (1, 2, 3):
            expected = {1: (4, 0, 14), 2: (5, 7, 8), 3: (6, 7, 9)}
            if (banks != expected[mode] or f["k"] != 64 or
                    any(f[n] for n in ("m_start", "kv_len", "query_start")) or
                    (f["layer"] != 0 if mode == 1 else f["layer"] >= 30)):
                raise ValueError("bad Q/K/V quantization")
        elif mode == 4:
            if (banks != (10, 0, 13) or f["k"] != f["kv_len"] or
                    not 1 <= f["kv_len"] <= 1024 or f["m_start"] or f["layer"] or
                    f["query_start"]+f["m_count"] > f["kv_len"]):
                raise ValueError("bad probability quantization")
        else:
            raise ValueError("reserved quantization mode")
    return command


def encode_weight_fragments(n, k, rows, weight_ddr_base, scale_ddr_base,
                            destination_bank, first_epoch=0):
    from pingpong_reference import build_isa_program
    if not 1 <= rows <= 32:
        raise ValueError("bad row count")
    result = []
    for fragment in build_isa_program(n, k, first_epoch=first_epoch):
        encoded = []
        for record in fragment:
            op = record["opcode"]
            if op == "END":
                value = 0
            elif op == "BANK_CONFIG":
                value = encode(op, (record["bank"], 0, 0), profile=4,
                               rows=record["n_count"], cols=k,
                               generation=record["epoch"]+1)
            elif op == "DMA_LOAD":
                base = weight_ddr_base if record["phase"] == "weight" else scale_ddr_base
                value = encode(op, (record["bank"], 0, 0),
                               local_byte_offset=record["bank_byte_offset"],
                               byte_count=record["byte_count"],
                               ddr_address=base+record["DDR_byte_offset"])
            else:
                value = encode(op, (13, record["bank"], destination_bank),
                               n_start=record["n_start"], n_total=n,
                               m_count=rows, k=k, n_tile=record["n_count"])
            validate_command(value)
            encoded.append(value)
        result.append(encoded)
    return result
