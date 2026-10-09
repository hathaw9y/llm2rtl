#!/usr/bin/env python3
"""Bind RoPE RTL vectors, OOC timing and fabric elaboration evidence."""
import hashlib
import json
import re
from pathlib import Path

design = Path(__file__).resolve().parents[1]
evidence = design / "evidence/smollm2_rope_executor/run_001"
vectors = design / "golden/rope_checkpoint"
cases = (("prefill", "q", 18432), ("prefill", "k", 6144),
         ("decode", "q", 576), ("decode", "k", 192),
         ("prefill_tail", "q", 18432), ("prefill_tail", "k", 6144))
for label, kind, elements in cases:
    log = (evidence / f"{label}_{kind}.log").read_text()
    match = re.search(r"PASS ROPE [qk] rows=\s*\d+ compared=\s*(\d+) "
                      r"exact_mismatch=\s*(\d+) over2ulp=\s*(\d+)", log)
    assert match and tuple(map(int, match.groups())) == (elements, 0, 0), (label, kind, log)
for negative in ("zero_rows", "too_many_rows", "wrong_bank", "nan_input"):
    assert f"PASS ROPE rejects {negative}" in (
        evidence / f"error_{negative}.log").read_text()

timing = (evidence / "timing_post_synth.rpt").read_text()
match = re.search(r"WNS\(ns\).*?\n\s*-+.*?\n\s*([-\d.]+)\s+",
                  timing, re.S)
assert match and float(match.group(1)) >= 0
wns = float(match.group(1))
assert "All user specified timing constraints are met." in timing
utilization = (evidence / "utilization_post_synth.rpt").read_text()
resources = {}
for key, label in (("lut", "CLB LUTs*"), ("ff", "CLB Registers"),
                   ("dsp", "DSPs")):
    match = re.search(r"^\|\s*" + re.escape(label) +
                      r"\s*\|\s*(\d+)", utilization, re.M)
    assert match, label
    resources[key] = int(match.group(1))
assert "Checks found: 0" in (evidence / "drc_post_synth.rpt").read_text()
assert "Built simulation snapshot tb_smollm2_rope_fabric_elab_sim" in (
    evidence / "fabric_elab_xelab.log").read_text()

sources = ("rtl/smollm2_rope_executor.sv", "rtl/isa_command_dispatcher.sv",
           "rtl/smollm2_gemm_dma_fabric_wide.sv", "isa_spec.json",
           "modules/rope_executor.json", "tb/tb_smollm2_rope_executor.sv",
           "scripts/generate_rope_checkpoint_vectors.py",
           "scripts/sweep_rope_checkpoint.py")
record = {
    "checkpoint_revision": "93efa2f097d58c2a74874c7e644dbc9b0cee75a2",
    "target": "ZCU104 xczu7ev-ffvc1156-2-e 150 MHz",
    "scope": "standalone Q/K BF16 RoPE, prefill32/decode1/tail positions 992..1023",
    "rtl_elements_compared": sum(elements for _, _, elements in cases),
    "rtl_exact_mismatches": 0,
    "negative_cases": 4,
    "ooc_setup_wns_ns": wns,
    "ooc_resources": resources,
    "fabric": "REAL_ROPE=1 elaborates; no routed integration or physical board execution",
    "source_sha256": {
        name: hashlib.sha256((design / name).read_bytes()).hexdigest()
        for name in sources
    },
    "vector_manifest_sha256": hashlib.sha256(
        (vectors / "manifest.json").read_bytes()).hexdigest(),
    "vector_sha256": {
        str(path.relative_to(vectors)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(vectors.rglob("*.hex"))
    },
    "sweep_sha256": hashlib.sha256(
        (vectors / "sweep.json").read_bytes()).hexdigest(),
    "physical_board": "pending",
}
(evidence / "verification.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
