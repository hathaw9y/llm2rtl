#!/usr/bin/env python3
"""Verify the routed cumulative attention ZCU104 handoff and source identity."""
import hashlib
import json
import re
import zipfile
from pathlib import Path

design = Path(__file__).resolve().parents[1]
artifacts = design / "dma_rms_gemm_rope_attention_add_board_probe" / "artifacts"
stem = "zcu104_dma_rms_gemm_rope_attention_add_board_probe"
names = [f"{stem}.{ext}" for ext in ("bit", "xsa", "hwh", "elf")]
names += ["psu_init.tcl", "run_on_zcu104.tcl"]


def digest(data):
    return hashlib.sha256(data).hexdigest()


hashes = {name: digest((artifacts / name).read_bytes()) for name in names}
assert (artifacts / "SHA256SUMS").read_text() == "".join(
    f"{hashes[name]}  {name}\n" for name in names)
with zipfile.ZipFile(artifacts / names[1]) as xsa:
    assert xsa.testzip() is None
    assert digest(xsa.read(names[0])) == hashes[names[0]]
    assert digest(xsa.read("system.hwh")) == hashes[names[2]]
    assert digest(xsa.read("psu_init.tcl")) == hashes["psu_init.tcl"]

timing = (artifacts / "routed_timing_summary.rpt").read_text()
match = re.search(
    r"WNS\(ns\).*?\n\s*-+.*?\n\s*([-\d.]+)\s+[-\d.]+\s+\d+\s+\d+\s+([-\d.]+).*?\s+([-\d.]+)\s+[-\d.]+\s+\d+\s+\d+\s*\n",
    timing, re.S)
assert match, "Timing summary missing"
wns, whs, wpws = map(float, match.groups())
assert min(wns, whs, wpws) >= 0, (wns, whs, wpws)
assert "All user specified timing constraints are met." in timing
clock = re.search(r"^clk_pl_0\s+\{[^}]+\}\s+([\d.]+)\s+([\d.]+)\s*$",
                  timing, re.M)
assert clock, "PL clock missing"
period, mhz = map(float, clock.groups())
assert 9.99 < period < 10.01 and 99.5 < mhz < 100.5, (period, mhz)

drc = (artifacts / "routed_drc.rpt").read_text()
assert not re.search(r"\|\s+\S+\s+\|\s+(Error|Critical Warning)\s+\|", drc)
utilization = (artifacts / "routed_utilization.rpt").read_text()
resources = {}
for key, label in (("lut", "CLB LUTs"), ("ff", "CLB Registers"),
                   ("bram_tile", "Block RAM Tile"), ("uram", "URAM"),
                   ("dsp", "DSPs")):
    match = re.search(r"^\|\s*" + re.escape(label) + r"\s*\|\s*(\d+(?:\.\d+)?)",
                      utilization, re.M)
    assert match, label
    resources[key] = float(match.group(1)) if key == "bram_tile" else int(match.group(1))

hwh = (artifacts / names[2]).read_text()
assert "axi_datamover" in hwh and "S_AXI_HP0_FPD" in hwh
for gpio, offset in (("gpio_ctl", "0xA0000000"),
                     ("gpio_hi", "0xA0010000"),
                     ("gpio_lo", "0xA0020000")):
    assert gpio in hwh and offset.lower() in hwh.lower()

sim = (design / "evidence/smollm2_dma_rms_gemm_rope_attention_board_probe/run_001/xsim.log").read_text()
assert re.search(r"PASS ATTN_SCORE SOFTMAX ATTN_VALUE rows=\s*1", sim)
assert len(re.findall(r"PASS ATTN_SCORE SOFTMAX ATTN_VALUE rows=\s*1", sim)) >= 2
assert re.search(r"PASS ATTN_SCORE SOFTMAX ATTN_VALUE rows=\s*32", sim)
assert "PASS smollm2_dma_rms_gemm_rope_attention_board_probe" in sim
assert re.search(r"PASS GEMM identity plus ADD rows=\s*32", sim)
assert re.search(r"PASS GEMM identity plus ADD rows=\s*1", sim)
add_sim = (design / "evidence/smollm2_add_executor/run_001/xsim.log").read_text()
assert "PASS ADD prefill rows=32 elements=18432 mismatches=0" in add_sim
assert "PASS ADD decode rows=1 elements=576 mismatches=0" in add_sim
assert "PASS ADD edge rows=1 elements=576 mismatches=0" in add_sim
assert "PASS ADD invalid row error response" in add_sim
module_sim = (design / "evidence/smollm2_gemm_attention_modes/run_001/xsim.log").read_text()
assert "PASS prefill_full score compare=" in module_sim
assert "PASS prefill_full context compare=" in module_sim
assert "PASS attention tile boundary N=193 K=193" in module_sim
assert "PASS decode1 score compare=" in module_sim
assert "PASS decode1 context compare=" in module_sim

sources = (
    "rtl/isa_command_dispatcher.sv",
    "rtl/smollm2_dma_control_fabric_wide.sv",
    "rtl/smollm2_gemm_dma_fabric_wide.sv",
    "rtl/smollm2_gemm_systolic_wide_executor.sv",
    "rtl/smollm2_rmsnorm_executor.sv",
    "rtl/smollm2_rope_executor.sv",
    "rtl/smollm2_softmax_executor.sv",
    "rtl/smollm2_add_executor.sv",
    "rtl/smollm2_softmax_exp_lut.svh",
    "rtl/smollm2_dma_gemm_board_probe.sv",
    "rtl/smollm2_dma_rms_gemm_rope_attention_board_probe_bd.v",
    "tb/tb_smollm2_dma_rms_gemm_rope_attention_board_probe.sv",
    "scripts/create_dma_rms_gemm_rope_attention_add_board_probe_100mhz.tcl",
    "scripts/build_dma_rms_gemm_rope_attention_add_board_probe_100mhz.tcl",
    "scripts/reset_dma_rms_gemm_rope_attention_add_board_probe_100mhz.tcl",
    "scripts/run_dma_rms_gemm_rope_attention_board_probe_xsim.sh",
    "scripts/generate_attention_board_vectors.py",
    "scripts/generate_attention_checkpoint_vectors.py",
    "scripts/generate_add_vectors.py",
    "scripts/generate_dispatcher.py",
    "scripts/run_add_executor_xsim.sh",
    "scripts/run_add_executor_ooc_100mhz.tcl",
    "scripts/build_dma_rms_gemm_rope_attention_add_board_app_existing_bsp.py",
    "dma_rms_gemm_rope_attention_add_board_probe/main.c",
    "dma_rms_gemm_rope_attention_add_board_probe/add_vectors.h",
    "dma_rms_gemm_rope_attention_board_probe/vectors.h",
    "dma_rms_gemm_rope_attention_add_board_probe/README.md",
    "tb/tb_smollm2_gemm_attention_modes.sv",
    "tb/tb_smollm2_add_executor.sv",
    "isa_spec.json",
    "isa_validation.json",
    "modules/add_executor.json",
    "scripts/run_gemm_attention_modes_xsim.sh",
)
board_report_path = design / "dma_rms_gemm_rope_attention_add_board_probe/board_run_user_report.json"
physical_board = "not yet run; awaiting user UART log"
if board_report_path.is_file():
    board_report = json.loads(board_report_path.read_text())
    handoff_tar = design / "attention_add_board_handoff_100mhz.tar.gz"
    assert digest(handoff_tar.read_bytes()) == board_report["handoff_tar_sha256"]
    assert board_report["checkpoint_revision"] == "93efa2f097d58c2a74874c7e644dbc9b0cee75a2"
    assert board_report["reported_final_marker"] in board_report["raw_user_message"]
    assert board_report["reported_mismatches"] == 0
    for phase, count in (("prefill32", 512), ("decode1", 16)):
        assert all(value == count for value in board_report["reported_comparisons"][phase].values())
        for op in ("Q", "score", "softmax", "context", "ADD"):
            label = "decode" if phase == "decode1" else phase
            assert f"{label} {op} compare={count} mismatches=0" in board_report["raw_user_message"]
    physical_board = {
        "status": "user_reported_pass",
        "report_path": str(board_report_path.relative_to(design)),
        "report_sha256": digest(board_report_path.read_bytes()),
        "artifact_identity_note": board_report["artifact_identity_note"],
        "scope": board_report["scope"],
    }
record = {
    "checkpoint_revision": "93efa2f097d58c2a74874c7e644dbc9b0cee75a2",
    "device": "xczu7ev-ffvc1156-2-e",
    "tool_version": "Vivado/Vitis 2025.2",
    "pl_clock_mhz": mhz,
    "scope": "DDR DMA_LOAD B0/B3/B7/B8/B9, PL RMSNorm/GEMM/RoPE, PL ATTN_SCORE/SOFTMAX/ATTN_VALUE, identity GEMM and BF16 ADD across three command BRAM chunks, prefill32/decode1",
    "routed_setup_wns_ns": wns,
    "routed_hold_whs_ns": whs,
    "routed_pulse_wpws_ns": wpws,
    "routed_resources": resources,
    "artifact_sha256": hashes,
    "source_sha256": {name: digest((design / name).read_bytes()) for name in sources},
    "vector_sha256": {path.name: digest(path.read_bytes()) for path in sorted(
        (design / "golden/add_checkpoint").glob("*.hex"))},
    "simulation": "shared GEMM attention mode standalone full prefill32 and decode1 score/context golden within 1/3 BF16 ULP; N=193/K=193 tile boundary PASS; integrated prefill32, focused one-key, and decode1 with kv_len=33 ISA programs PASS; synthetic identity GEMM and ADD verify the first 16 residual values per row within 16 BF16 ULP",
    "physical_board": physical_board,
}
(artifacts / "verification.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
