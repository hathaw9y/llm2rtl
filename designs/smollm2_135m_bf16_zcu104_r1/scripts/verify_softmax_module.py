#!/usr/bin/env python3
"""Bind Softmax golden, RTL simulation, OOC and integration evidence."""
import hashlib
import json
import re
from pathlib import Path

design = Path(__file__).resolve().parents[1]
evidence = design / "evidence/smollm2_softmax_executor/run_001"
vectors = design / "golden/softmax_checkpoint"
log = (evidence / "xsim.log").read_text()
for case, count in (("prefill32", 9216), ("decode1", 360), ("context1024", 9216)):
    assert f"PASS SOFTMAX {case} compare={count} mismatches=0 max_ulp=1" in log
assert "PASS smollm2_softmax_executor" in log
integration = (design / "evidence/smollm2_dma_rms_gemm_rope_softmax_board_probe"
               / "run_001/xsim.log").read_text()
for rows in (1, 32):
    assert f"PASS DMA_LOAD RMSNORM GEMM ROPE SOFTMAX rows={rows}" in integration
assert "PASS smollm2_dma_rms_gemm_rope_softmax_board_probe" in integration

timing = (evidence / "timing_post_synth.rpt").read_text()
match = re.search(r"WNS\(ns\).*?\n\s*-+.*?\n\s*([-\d.]+)\s+", timing, re.S)
assert match and float(match.group(1)) >= 0
wns = float(match.group(1))
assert "All user specified timing constraints are met." in timing
utilization = (evidence / "utilization_post_synth.rpt").read_text()
resources = {}
for key, label in (("lut", "CLB LUTs*"), ("ff", "CLB Registers"),
                   ("bram_tile", "Block RAM Tile"), ("dsp", "DSPs")):
    match = re.search(r"^\|\s*" + re.escape(label) +
                      r"\s*\|\s*(\d+(?:\.\d+)?)", utilization, re.M)
    assert match, label
    resources[key] = float(match.group(1)) if key == "bram_tile" else int(match.group(1))

sources = (
    "rtl/smollm2_softmax_executor.sv", "rtl/smollm2_softmax_exp_lut.svh",
    "rtl/smollm2_gemm_dma_fabric_wide.sv", "rtl/isa_command_dispatcher.sv",
    "isa_spec.json", "modules/softmax_executor.json",
    "tb/tb_smollm2_softmax_executor.sv",
    "scripts/generate_softmax_checkpoint_vectors.py",
    "scripts/run_softmax_executor_xsim.sh", "scripts/run_softmax_ooc.tcl",
)
digest = lambda data: hashlib.sha256(data).hexdigest()
record = {
    "checkpoint_revision": "93efa2f097d58c2a74874c7e644dbc9b0cee75a2",
    "target": "ZCU104 xczu7ev-ffvc1156-2-e 150 MHz",
    "scope": "standalone causal Softmax, prefill32/decode1 checkpoint score, synthetic 1024-position score",
    "rtl_elements_compared": 18792,
    "rtl_over_2ulp": 0,
    "max_observed_ulp": 1,
    "negative_cases": 5,
    "ooc_setup_wns_ns": wns,
    "ooc_resources": resources,
    "integration": "cumulative RTL XSIM prefill32/decode1 passed with GPIO score probe; ATTN_SCORE arithmetic pending",
    "source_sha256": {name: digest((design / name).read_bytes()) for name in sources},
    "vector_manifest_sha256": digest((vectors / "manifest.json").read_bytes()),
    "vector_sha256": {path.name: digest(path.read_bytes()) for path in sorted(vectors.glob("*.hex"))},
    "physical_board": "pending",
}
(evidence / "verification.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
