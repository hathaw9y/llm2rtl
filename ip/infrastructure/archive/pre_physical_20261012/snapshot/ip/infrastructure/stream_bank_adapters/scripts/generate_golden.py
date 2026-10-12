#!/usr/bin/env python3
import json
from pathlib import Path

def keep_for_count(count: int) -> int:
    rem = count % 8
    return 0xFF if rem == 0 else (1 << rem) - 1

report = {
    "schema": "llm2rtl.stream_bank_adapters.golden.v1",
    "packing_order": "low AXIS beat to low native-word slice",
    "mm2s_24_bytes": {
        "write_addresses": [4, 5],
        "write_strobes_hex": ["ffff", "000f"],
    },
    "s2mm_150_bytes": {
        "native_requests": 2,
        "axis_beats": 19,
        "final_keep_hex": f"{keep_for_count(150):02x}",
        "last_beat_index": 18,
    },
    "zero_count": {"native_requests": 0, "axis_beats": 0},
}

out = Path(__file__).resolve().parents[1] / "evidence" / "run_001" / "golden_report.json"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(report, indent=2) + "\n")
print(out)
