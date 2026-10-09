#!/usr/bin/env python3
"""Verify the unchanged BIT and new actual-o_proj A53 test handoff."""
import hashlib
import json
import re
import zipfile
from pathlib import Path

design = Path(__file__).resolve().parents[1]
base = design / "dma_rms_gemm_rope_attention_add_board_probe/artifacts"
dest = design / "first_layer_attention_output_board_probe/artifacts"
base_record = json.loads((base / "verification.json").read_text())
gold = design / "golden/first_layer_attention_output"
manifest = json.loads((gold / "manifest.json").read_text())
stem = "zcu104_dma_rms_gemm_rope_attention_add_board_probe"
names = [f"{stem}.{ext}" for ext in ("bit", "xsa", "hwh")]
names += ["zcu104_first_layer_attention_output_probe.elf", "psu_init.tcl",
          "run_on_zcu104.tcl"]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


hashes = {name: digest(dest / name) for name in names}
assert (dest / "SHA256SUMS").read_text() == "".join(
    f"{hashes[name]}  {name}\n" for name in names)
for name in names[:3] + ["psu_init.tcl"]:
    assert hashes[name] == base_record["artifact_sha256"][name], name
for name, expected in base_record["source_sha256"].items():
    assert digest(design / name) == expected, name
with zipfile.ZipFile(dest / f"{stem}.xsa") as xsa:
    assert xsa.testzip() is None
    assert hashlib.sha256(xsa.read(f"{stem}.bit")).hexdigest() == hashes[f"{stem}.bit"]
    assert hashlib.sha256(xsa.read("system.hwh")).hexdigest() == hashes[f"{stem}.hwh"]
    assert hashlib.sha256(xsa.read("psu_init.tcl")).hexdigest() == hashes["psu_init.tcl"]
assert manifest["checkpoint_revision"] == base_record["checkpoint_revision"]
assert all(manifest["cases"][case]["context_projection_matches_hf_bitwise"]
           for case in ("prefill32", "decode1"))

sim = (design / "evidence/smollm2_first_layer_attention_output_probe/run_001/xsim.log").read_text()
for rows in (32, 1):
    assert re.search(rf"PASS first-layer o_proj rows=\s*{rows}", sim)
    assert re.search(rf"PASS first-layer attention residual rows=\s*{rows}", sim)
assert "PASS smollm2_first_layer_attention_output_probe" in sim
for kind, rows, count in ((5, 32, 512), (6, 32, 512),
                          (5, 1, 16), (6, 1, 16)):
    assert re.search(rf"PASS kind=\s*{kind} rows=\s*{rows} compare=\s*{count} mismatches=0", sim)

sources = (
    "scripts/generate_first_layer_attention_output_vectors.py",
    "scripts/run_first_layer_attention_output_probe_xsim.sh",
    "scripts/build_first_layer_attention_output_board_app.py",
    "scripts/verify_first_layer_attention_output_board_artifacts.py",
    "first_layer_attention_output_board_probe/main.c",
    "first_layer_attention_output_board_probe/vectors.h",
    "first_layer_attention_output_board_probe/README.md",
    "tb/tb_smollm2_first_layer_attention_output_probe.sv",
)
board_report_path = design / "first_layer_attention_output_board_probe/board_run_user_report.json"
physical_board = "pending user UART report"
if board_report_path.is_file():
    board_report = json.loads(board_report_path.read_text())
    handoff_tar = design / "first_layer_attention_output_board_handoff_100mhz.tar.gz"
    assert digest(handoff_tar) == board_report["handoff_tar_sha256"]
    assert board_report["checkpoint_revision"] == manifest["checkpoint_revision"]
    assert board_report["reported_final_marker"] in board_report["raw_user_message"]
    assert board_report["reported_mismatches"] == 0
    for phase, count in (("prefill32", 512), ("decode1", 16)):
        for op in ("Q", "score", "softmax", "context", "o_proj", "residual"):
            assert board_report["reported_comparisons"][phase][op] == count
            label = "decode" if phase == "decode1" else phase
            assert f"{label} {op} compare={count} mismatches=0" in board_report["raw_user_message"]
    physical_board = {
        "status": "user_reported_pass",
        "report_path": str(board_report_path.relative_to(design)),
        "report_sha256": digest(board_report_path),
        "artifact_identity_note": board_report["artifact_identity_note"],
        "scope": board_report["scope"],
    }
record = {
    "checkpoint_revision": manifest["checkpoint_revision"],
    "checkpoint_file_sha256": manifest["checkpoint_file_sha256"],
    "device": "xczu7ev-ffvc1156-2-e",
    "tool_version": "Vivado/Vitis 2025.2",
    "pl_clock_mhz": 100,
    "scope": "First-layer checkpoint o_proj and post-attention residual, prefill32 and decode1, first 16 BF16 outputs per row; Q/score/softmax/context checked in the same program",
    "readback_limit": "Existing B5 GPIO tap exposes first 16 elements per row; all 576 elements are computed in PL but only 16 per row are compared on board",
    "hardware_reuse": "BIT/XSA/HWH/psu_init byte-identical to prior routed ADD probe",
    "base_routed_timing": {key: base_record[key] for key in (
        "routed_setup_wns_ns", "routed_hold_whs_ns", "routed_pulse_wpws_ns")},
    "base_routed_resources": base_record["routed_resources"],
    "artifact_sha256": hashes,
    "source_sha256": {name: digest(design / name) for name in sources},
    "golden_sha256": {path.name: digest(path) for path in sorted(gold.glob("*.hex"))},
    "reference": "HF eager BF16 layer0 self_attn output after real o_proj and input residual; pinned context projection is bitwise equal to HF output",
    "acceptance": "Q <=8 BF16 ULP; score, softmax, context <=16 ULP; o_proj and residual <=16 ULP or <=0.002 absolute BF16 value error",
    "simulation": "integrated prefill32/decode1 checkpoint o_proj and residual first 16 outputs per row PASS",
    "physical_board": physical_board,
}
(dest / "verification.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
