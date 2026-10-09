#!/usr/bin/env python3
"""Verify matched routed ZCU104 smoke artifacts and record their scope."""
import hashlib
import json
import re
import zipfile
from pathlib import Path

design = Path(__file__).resolve().parents[1]
artifacts = design / "board_smoke" / "artifacts"
names = ["zcu104_gemm_board_smoke.bit", "zcu104_gemm_board_smoke.xsa",
         "zcu104_gemm_board_smoke.hwh", "zcu104_gemm_board_smoke.elf"]
sha = lambda data: hashlib.sha256(data).hexdigest()
file_hashes = {name: sha((artifacts / name).read_bytes()) for name in names}

with zipfile.ZipFile(artifacts / names[1]) as xsa:
    assert xsa.testzip() is None
    assert sha(xsa.read(names[0])) == file_hashes[names[0]]
    assert sha(xsa.read("system.hwh")) == file_hashes[names[2]]
    assert "psu_init.tcl" in xsa.namelist()

timing = (artifacts / "routed_timing_summary.rpt").read_text()
match = re.search(r"WNS\(ns\).*?\n\s*-+.*?\n\s*([-\d.]+)\s+[-\d.]+\s+\d+\s+\d+\s+([-\d.]+).*?\s+([-\d.]+)\s+[-\d.]+\s+\d+\s+\d+\s*\n", timing, re.S)
assert match, "Timing summary not found"
wns, whs, wpws = map(float, match.groups())
assert min(wns, whs, wpws) >= 0.0, (wns, whs, wpws)
assert "All user specified timing constraints are met." in timing

drc = (artifacts / "routed_drc.rpt").read_text()
assert not re.search(r"\|\s+\S+\s+\|\s+(Error|Critical Warning)\s+\|", drc)
utilization = (artifacts / "routed_utilization.rpt").read_text()
resources = {}
for key, label in (("lut", "CLB LUTs"), ("ff", "CLB Registers"),
                   ("bram_tile", "Block RAM Tile"), ("uram", "URAM"),
                   ("dsp", "DSPs")):
    match = re.search(r"^\|\s*" + re.escape(label) + r"\s*\|\s*(\d+)",
                      utilization, re.M)
    assert match, label
    resources[key] = int(match.group(1))

record = {
    "checkpoint_revision": "93efa2f097d58c2a74874c7e644dbc9b0cee75a2",
    "device": "xczu7ev-ffvc1156-2-e",
    "tool_version": "Vivado/Vitis 2025.2",
    "pl_clock_mhz": 200,
    "scope": "layer0 q_proj, first 16 columns, prefill32 and decode1",
    "routed_setup_wns_ns": wns,
    "routed_hold_whs_ns": whs,
    "routed_pulse_wpws_ns": wpws,
    "routed_resources": resources,
    "artifact_sha256": file_hashes,
    "source_sha256": {
        name: sha((design / name).read_bytes()) for name in (
            "rtl/smollm2_gemm_systolic_wide_executor.sv",
            "rtl/smollm2_gemm_board_smoke.sv",
            "board_smoke/main.c", "board_smoke/vectors.h")
    },
    "simulation": {
        "standalone_gemm_checkpoint": "PASS",
        "gemm_bank_integration": "PASS",
        "board_smoke_protocol": "PASS"
    },
    "physical_board": "not yet run; awaiting user UART log"
}
(artifacts / "verification.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
