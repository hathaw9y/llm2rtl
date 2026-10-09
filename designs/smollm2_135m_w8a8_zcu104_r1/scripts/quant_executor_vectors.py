"""Quantization local-bank fixtures; test-only tensor math, never PS runtime."""
import gzip
import hashlib
import json
from fractions import Fraction
from functools import lru_cache
from pathlib import Path

import exact_numeric as n
from isa_codec import SPEC, decode, encode
from isa_interpreter import LAYOUT, align16, pack16, pack32

D = Path(__file__).resolve().parents[1]
OUT = D / "tb/quant_executor_vectors"
CASES = []


def digest(data):
    return hashlib.sha256(data).hexdigest()


def writehex(path, data):
    data = bytes(data) + bytes((-len(data)) % 16)
    path.write_text("".join(f"{int.from_bytes(data[i:i+16], 'little'):032x}\n"
                            for i in range(0, len(data), 16)))


def descriptor(profile, rows, cols, generation=1, position=0, layer=0):
    return dict(present=1, profile=SPEC["profile_encodings"][profile], rows=rows,
                cols=cols, position=position, layer=layer, generation=generation,
                data_valid=1, scale_valid=1, busy=1, owner=0)


def make_case(name, record, src_data, src_desc, output_data, output_scales=b"",
              src_scales=b"", table=None, table_generation=1, lanes=None,
              output_generation=0, golden_command_id=None):
    command = decode(record)
    fields, ids, op = command["fields"], command["banks"], command["opcode"]
    static = op == "QUANTIZE" and fields["mode"] in (2, 3)
    folder = OUT / name
    folder.mkdir(parents=True, exist_ok=True)
    meta_banks = []
    roles = (21, 22 if static else 0, 23) if op == "QUANTIZE" else (24, 0, 25)
    generations = [src_desc["generation"], table_generation if static else 0, output_generation]
    for slot, bank_id in enumerate(ids):
        info = LAYOUT["banks"][bank_id]
        data = bytearray(info["capacity_bytes"])
        if slot == 0:
            assert len(src_data) <= info["payload_capacity_bytes"]
            data[:len(src_data)] = src_data
            if src_scales:
                off = info["scale_region_byte_offset"]
                data[off:off+len(src_scales)] = src_scales
            desc = dict(src_desc)
        elif slot == 1 and static:
            assert len(table) == 1920
            data[:4096] = bytes([0x5a]) * 4096
            data[4096:6016] = table
            desc = descriptor("RoPE_and_static_KV_scales", 32, 64,
                              table_generation, position=777)
            desc["data_valid"] = 0  # RoPE window validity is irrelevant.
            desc["scale_valid"] = 0
        elif slot == 1:
            desc = dict(present=0, profile=0, rows=0, cols=0, position=0, layer=0,
                        generation=0, data_valid=0, scale_valid=0, busy=0, owner=0)
        else:
            data[:] = bytes([0xa5]) * len(data)
            desc = dict(present=0, profile=0, rows=0, cols=0, position=0, layer=0,
                        generation=output_generation, data_valid=0, scale_valid=0,
                        busy=1, owner=roles[slot])
        desc["owner"] = roles[slot]
        # Unused encoded B0 may alias the real DQ destination; never overwrite it.
        filename = f"slot{slot}_bank{bank_id}.hex"
        writehex(folder / filename, data)
        meta_banks.append(dict(bank=bank_id, capacity_bytes=len(data), initial_file=filename,
                               initial_sha256=digest(data), descriptor=desc))
    info = LAYOUT["banks"][ids[2]]
    expected = bytearray([0xa5]) * info["capacity_bytes"]
    mask = bytearray(len(expected))
    assert len(output_data) <= info["payload_capacity_bytes"]
    expected[:len(output_data)] = output_data
    mask[:len(output_data)] = bytes([1]) * len(output_data)
    if output_scales:
        off = info["scale_region_byte_offset"]
        assert len(output_scales) <= info["scale_region_capacity_bytes"]
        expected[off:off+len(output_scales)] = output_scales
        mask[off:off+len(output_scales)] = bytes([1]) * len(output_scales)
    writehex(folder / "expected.hex", expected)
    writehex(folder / "expected_write_mask.hex", mask)
    lanes = lanes or {}
    packed_lanes = sum(int(lane) << (2 * int(row)) for row, lane in lanes.items())
    valid_lanes = sum(1 << int(row) for row in lanes)
    mode = fields["mode"]
    profile = "hidden" if op == "DEQUANTIZE" else ["A_INT8", "Q_INT8", "K_current_or_cache_INT8",
                                                  "V_current_or_cache_INT8", "probability_INT8"][mode]
    cols = 576 if op == "DEQUANTIZE" or mode == 1 else (fields["k"] if mode == 0 else
                                                        (fields["kv_len"] if mode == 4 else 192))
    meta = dict(name=name, hex128=f"{record:032x}", opcode=op, fields=fields,
                transaction_id=0x91340000 + len(CASES), generations=generations,
                banks=meta_banks, cmd_b7_static_valid=int(static),
                cmd_embedding_lanes=packed_lanes, cmd_embedding_lane_valid=valid_lanes,
                embedding_lanes=lanes, expected_file="expected.hex",
                expected_write_mask="expected_write_mask.hex", expected_sha256=digest(expected),
                expected_write_bytes=sum(mask), expected_status=0, producer_begin_expected=True,
                producer_generation=output_generation+1, producer_profile=SPEC["profile_encodings"][profile],
                producer_rows=fields["m_count"], producer_cols=cols,
                producer_position=fields["query_start"] if op == "QUANTIZE" and mode == 4 else 0,
                producer_layer=fields["layer"] if static else 0, golden_command_id=golden_command_id,
                comparison="Exact-once selected bytes and full allocation comparison; other bytes remain0xa5; source banks unchanged")
    (folder / "case.json").write_text(json.dumps(meta, indent=2) + "\n")
    CASES.append(dict(name=name, path=str(folder.relative_to(D)),
                      metadata_sha256=digest((folder / "case.json").read_bytes())))


def stored():
    root = D / "verification/tensor_golden"
    manifest = json.loads((root / "manifest.json").read_text())
    ledger = json.loads((root / "command_ledger.json").read_text())
    chosen = {}
    for vector in manifest["vectors"]:
        if vector["opcode"] not in ("QUANTIZE", "DEQUANTIZE"):
            continue
        c = decode(int(vector["hex128"], 16))
        f = c["fields"]
        key = (vector["workload"], c["opcode"], f["mode"], f["k"])
        chosen.setdefault(key, vector)
    for key, vector in chosen.items():
        c = decode(int(vector["hex128"], 16)); f = c["fields"]
        event = ledger[vector["command_id"] - 1]
        src = vector["inputs"][0]
        def load(component):
            raw = gzip.decompress((root / component["file"]).read_bytes())
            assert digest(raw) == component["sha256"]
            return raw
        data = load(src["components"]["data"])
        scales = load(src["components"]["scale"]) if "scale" in src["components"] else b""
        op, mode = c["opcode"], f["mode"]
        width = 576 if op == "DEQUANTIZE" or mode == 1 else (f["k"] if mode == 0 else
                                                              (9 * align16(f["kv_len"]) if mode == 4 else 192))
        rows = len(data) // (width * (1 if op == "DEQUANTIZE" else 2))
        cols = f["kv_len"] if mode == 4 else width
        desc = descriptor(src["profile"], rows, cols, src["generation"],
                          position=f["query_start"] if mode == 4 else 0)
        table = load(vector["inputs"][1]["components"]["static"]) if len(vector["inputs"]) == 2 else None
        table_gen = vector["inputs"][1]["generation"] if table is not None else 0
        before = event["before"][str(c["banks"][0])]
        lanes = before["embedding_lanes"] if op == "DEQUANTIZE" else None
        outgen = event["before"][str(c["banks"][2])]["generation"]
        outdata = load(vector["outputs"]["data"])
        outscale = load(vector["outputs"]["scale"]) if "scale" in vector["outputs"] else b""
        name = f"golden_{key[0]}_{op}_mode{mode}_K{f['k']}"
        make_case(name, int(vector["hex128"], 16), data, desc, outdata, outscale,
                  scales, table, table_gen, lanes, outgen, vector["command_id"])


@lru_cache(maxsize=10000)
def q(value, scale, unsigned=False):
    return n.quantize(value, scale, unsigned) & 255


def dynamic(name, mode, rows, width, source_rows=None, start=0, position=0,
            values=None, profile=None):
    source_rows = source_rows or rows
    heads = 1 if mode == 0 else 9
    stride = width if mode == 0 else (64 if mode == 1 else align16(width))
    logical_width = heads * stride
    if values is None:
        values = []
        for row in range(source_rows):
            for head in range(heads):
                for col in range(stride):
                    if mode == 4 and (col >= width or col > position + row):
                        value = 0x7fc1 if col & 1 else 0xff80
                    else:
                        value = n.bf16(Fraction((head+1)*(1+row//16), 8) * (-1 if col%7 == 0 else 1))
                    values.append(value)
    selected = values[start*logical_width:(start+rows)*logical_width]
    groups = (rows + 15) // 16
    scales = []
    result = bytearray(len(selected))
    for head in range(heads):
        for group in range(groups):
            indices = [row*logical_width+head*stride+col
                       for row in range(group*16, min(rows, (group+1)*16))
                       for col in range(stride)
                       if mode != 4 or col < width and col <= position+row]
            scale = n.dynamic_scale([selected[i] for i in indices], mode == 4)
            scales.append(scale)
            for index in indices:
                result[index] = q(selected[index], scale, mode == 4)
    profile = profile or {0: "norm_output", 1: "Q_BF16", 4: "probability_BF16"}[mode]
    src = {"norm_output":2, "context_BF16":11, "SiLU_BF16":10, "Q_BF16":4,
           "probability_BF16":10}[profile]
    dst = 14 if mode == 1 else 13
    fields = dict(mode=mode, m_start=start, m_count=rows, k=width if mode in (0,4) else 64)
    if mode == 4:
        fields.update(kv_len=width, query_start=position)
    data_scales = pack32(scales)
    data_scales += bytes((-len(data_scales)) % 16)
    make_case(name, encode("QUANTIZE", (src,0,dst), **fields), pack16(values),
              descriptor(profile, source_rows, width if mode == 4 else logical_width,
                         position=position if mode == 4 else 0), result, data_scales)


def static(name, mode, rows, layer, scale_values, source_rows=None, value=0x3f80):
    source_rows = source_rows or rows
    table = bytearray(1920)
    # Deliberately invalid unused K fourth lane and all other layer scales.
    table[:] = pack32([0x7fc00000] * 480)
    base = layer * 64 + (0 if mode == 2 else 16)
    table[base:base+4*len(scale_values)] = pack32(scale_values)
    source = [value if (i % 7) else value ^ 0x8000 for i in range(source_rows*192)]
    result = bytes(q(source[row*192+head*64+col],
                     scale_values[head if mode == 2 else head*4+col//16])
                   for row in range(rows) for head in range(3) for col in range(64))
    outscale = pack32(scale_values)
    outscale += bytes((-len(outscale)) % 16)
    make_case(name, encode("QUANTIZE", (5 if mode == 2 else 6,7,8 if mode == 2 else 9),
                          mode=mode, m_count=rows, k=64, layer=layer), pack16(source),
              descriptor("K_BF16" if mode == 2 else "V_BF16", source_rows,192),
              result, outscale, table=table, table_generation=42)


def embedding(name, rows, tiny=False):
    lanes = {row:row%4 for row in range(rows)}
    scales = []
    values = []
    expected = []
    for row in range(rows):
        scale = 1 if tiny else n.f32(Fraction(row+1,128))
        block = [0x7fc00000, 0x7f800000, 0xbf800000, 0]
        block[lanes[row]] = scale
        scales += block
        for col in range(576):
            v = -1 if tiny else (col%255)-127
            values.append(v & 255)
            expected.append(n.dequantize(v,scale))
    make_case(name, encode("DEQUANTIZE",(3,0,0),mode=0,m_count=rows,k=576),
              bytes(values), descriptor("embedding_rows_INT8",rows,576), pack16(expected),
              src_scales=pack32(scales), lanes=lanes, output_generation=7)


def directed():
    dynamic("direct_A1_zero_K576",0,1,576,values=[0]*576)
    dynamic("direct_A16_subnormal_K576",0,16,576,values=[1 if i%3 else 0x8001 for i in range(16*576)])
    dynamic("direct_A17_mstart15_K1536",0,17,1536,source_rows=32,start=15,profile="SiLU_BF16")
    dynamic("direct_A32_K1536",0,32,1536,profile="SiLU_BF16")
    dynamic("direct_A1_context_K576",0,1,576,profile="context_BF16")
    dynamic("direct_Q17_prefix32_groups",1,17,64,source_rows=32)
    for length in [1,15,16,17,33,1024]:
        dynamic(f"direct_P1_L{length}_masked_nonfinite",4,1,length,position=length-1)
    dynamic("direct_P17_L33_prefix32_groups",4,17,33,source_rows=32,position=1)
    dynamic("direct_P32_L1024_max_capacity",4,32,1024,position=992)
    dynamic("direct_P1_L1_all_negative",4,1,1,values=[0xbf80 if col == 0 else 0x7fc1 for head in range(9) for col in range(16)])
    static("direct_K1_layer29_prefix32_double_round",2,1,29,[0x3f2aaaab]*3,source_rows=32)
    static("direct_K16_layer0_quotient_overflow",2,16,0,[1]*3,value=0x7f7f)
    static("direct_V17_layer29_prefix32_groups",3,17,29,[n.f32(Fraction(i+1,128)) for i in range(12)],source_rows=32)
    embedding("direct_DQ32_all_lanes_unused_nonfinite",32)
    embedding("direct_DQ1_signed_zero",1,tiny=True)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    stored()
    directed()
    manifest = dict(schema="llm2rtl.quantization_executor_vectors.v1",
                    scope="Standalone local-bank exact quantization/dequantization fixtures; no full-model/board claim",
                    count=len(CASES), cases=CASES, source_sha256=digest(Path(__file__).read_bytes()),
                    golden_manifest_sha256=digest((D/"verification/tensor_golden/manifest.json").read_bytes()))
    (OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print(json.dumps(dict(cases=len(CASES),path=str(OUT)),indent=2))
