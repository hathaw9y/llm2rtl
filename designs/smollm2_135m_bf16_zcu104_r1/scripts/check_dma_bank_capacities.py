#!/usr/bin/env python3
"""Keep DataMover descriptors aligned with logical and physical bank sizes."""
import json
from pathlib import Path
import re

design = Path(__file__).resolve().parents[1]
layout = json.loads((design / "bank_layout.json").read_text())
physical = json.loads((design / "modules/smollm2_bank_memories.json").read_text())
link = json.loads((design / "modules/smollm2_dma_engine_link.json").read_text())
rtl = (design / "rtl/smollm2_dma_engine_link.sv").read_text()

logical_bytes = [bank["capacity_words"] * (bank["word_bits"] // 8)
                 for bank in layout["banks"]]
physical_bytes = [words * 16 for words in physical["capacity_words_by_bank"]]
declared_bytes = link["interface"]["bank_capacity_bytes_by_id"]
packed_body = rtl.split("localparam logic [415:0] BANK_CAPACITY_BYTES = {", 1)[1].split("};", 1)[0]
packed_bytes = [int(value) for value in re.findall(r"32'd(\d+)", packed_body)]
if len(logical_bytes) != 13 or not (logical_bytes == physical_bytes == declared_bytes):
    raise SystemExit("logical, XPM and DataMover capacity tables differ")
if packed_bytes != list(reversed(declared_bytes)):
    raise SystemExit("DataMover packed capacity order differs from bank IDs")
print("PASS 13 DataMover capacities match logical tensors, XPM banks and packed engine table")
