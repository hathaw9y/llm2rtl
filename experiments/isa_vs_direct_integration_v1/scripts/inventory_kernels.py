#!/usr/bin/env python3
"""Inventory only standalone compute files; no integrated source or old PASS."""
import argparse
import hashlib
import json
import re
from pathlib import Path

STUDY = Path(__file__).resolve().parents[1]
REPO = STUDY.parents[1]
FILES = [
    "smollm2_gemm_systolic_wide_executor.sv",
    "smollm2_rmsnorm_executor.sv",
    "smollm2_rope_executor.sv",
    "smollm2_softmax_executor.sv",
    "smollm2_softmax_exp_lut.svh",
    "smollm2_silu_mul_executor.sv",
    "smollm2_silu_bf16_lut.mem",
    "smollm2_add_executor.sv",
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=STUDY / "kernel_inventory.json")
    args = parser.parse_args()
    root = REPO / "designs/smollm2_135m_bf16_zcu104_r1/rtl"
    entries = []
    for name in FILES:
        path = root / name
        raw = path.read_bytes()
        source = raw.decode()
        entries.append({
            "file": name,
            "origin": str(path.relative_to(REPO)),
            "sha256": hashlib.sha256(raw).hexdigest(),
            "bytes": len(raw),
            "modules": re.findall(r"^module\s+(\w+)", source, re.M),
            "includes": re.findall(r'`include\s+"([^"]+)"', source),
        })
    report = {
        "scope": "source inventory only; fresh qualification pending",
        "control_rtl_provided": False,
        "files": entries,
        "identity_sha256": hashlib.sha256(
            json.dumps(entries, sort_keys=True).encode()
        ).hexdigest(),
    }
    args.out.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"files": len(entries), "identity_sha256": report["identity_sha256"]}))


if __name__ == "__main__":
    main()
