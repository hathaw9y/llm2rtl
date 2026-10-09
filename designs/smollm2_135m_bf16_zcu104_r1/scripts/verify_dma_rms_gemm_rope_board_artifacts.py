#!/usr/bin/env python3
"""Verify the routed RMSNorm+GEMM+RoPE ZCU104 handoff and source identity."""
import hashlib
import json
import re
import zipfile
from pathlib import Path

design = Path(__file__).resolve().parents[1]
artifacts = design / "dma_rms_gemm_rope_board_probe" / "artifacts"
stem = "zcu104_dma_rms_gemm_rope_board_probe"
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
assert 6.65 < period < 6.68 and 149.5 < mhz < 150.5, (period, mhz)

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

sim = (design / "evidence/smollm2_dma_rms_gemm_rope_board_probe/run_001/xsim.log").read_text()
assert "PASS DMA_LOAD RMSNORM GEMM ROPE rows=1" in sim
assert "PASS DMA_LOAD RMSNORM GEMM ROPE rows=32" in sim
assert "PASS smollm2_dma_rms_gemm_rope_board_probe" in sim

sources = (
    "rtl/isa_command_dispatcher.sv",
    "rtl/smollm2_dma_control_fabric_wide.sv",
    "rtl/smollm2_gemm_dma_fabric_wide.sv",
    "rtl/smollm2_gemm_systolic_wide_executor.sv",
    "rtl/smollm2_rmsnorm_executor.sv",
    "rtl/smollm2_rope_executor.sv",
    "rtl/smollm2_dma_gemm_board_probe.sv",
    "rtl/smollm2_dma_rms_gemm_rope_board_probe_bd.v",
    "tb/tb_smollm2_dma_rms_gemm_rope_board_probe.sv",
    "scripts/create_dma_rms_gemm_rope_board_probe_v1.tcl",
    "scripts/build_dma_rms_gemm_rope_board_probe_v1.tcl",
    "scripts/run_dma_rms_gemm_rope_board_probe_xsim.sh",
    "scripts/generate_rms_gemm_rope_board_vectors.py",
    "scripts/build_dma_rms_gemm_rope_board_app_existing_bsp.py",
    "dma_rms_gemm_rope_board_probe/main.c",
    "dma_rms_gemm_rope_board_probe/vectors.h",
    "dma_rms_gemm_rope_board_probe/README.md",
)
board_evidence = (design / "evidence/smollm2_dma_rms_gemm_rope_board_probe"
                  / "board_150mhz/run_001/user_uart_report.json")
physical_board = "not yet run; awaiting user UART log"
if board_evidence.is_file():
    reported = json.loads(board_evidence.read_text())
    assert reported["checkpoint_revision"] == "93efa2f097d58c2a74874c7e644dbc9b0cee75a2"
    assert reported["bit_sha256_at_handoff"] == hashes[names[0]]
    assert reported["elf_sha256_at_handoff"] == hashes[names[3]]
    checks = reported["checks"]
    assert checks["board_result"] == "PASS"
    for stage, count in (("prefill", 512), ("decode", 16)):
        for bank in ("q", "k"):
            assert checks[f"{stage}_{bank}_rope_compared"] == count
            assert checks[f"{stage}_{bank}_rope_mismatches"] == 0
    physical_board = {
        "status": "user-reported PASS",
        "evidence": str(board_evidence.relative_to(design)),
        "host_hash_output_received": reported["host_hash_output_received"],
        "scope": reported["scope"],
        "limitation": reported["limitation"],
    }
record = {
    "checkpoint_revision": "93efa2f097d58c2a74874c7e644dbc9b0cee75a2",
    "device": "xczu7ev-ffvc1156-2-e",
    "tool_version": "Vivado/Vitis 2025.2",
    "pl_clock_mhz": mhz,
    "scope": "DDR DMA_LOAD B0/B3, PL RMSNorm B2, DDR DMA_LOAD B3 one-hot projection, PL GEMM Q B4/K B5, DDR DMA_LOAD B7 coefficients, PL RoPE Q/K, prefill32/decode1",
    "routed_setup_wns_ns": wns,
    "routed_hold_whs_ns": whs,
    "routed_pulse_wpws_ns": wpws,
    "routed_resources": resources,
    "artifact_sha256": hashes,
    "source_sha256": {name: digest((design / name).read_bytes()) for name in sources},
    "vector_sha256": {path.name: digest(path.read_bytes()) for path in sorted(
        (design / "dma_rms_gemm_rope_board_probe").glob("*.hex"))},
    "simulation": "PASS prefill32 and decode1, first 16 Q/K values per row within 2 BF16 ULP; checkpoint RMS input/gamma and RoPE coefficients, synthetic one-hot projection",
    "physical_board": physical_board,
}
(artifacts / "verification.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
