#!/usr/bin/env python3
"""Check that the routed DMA+GEMM probe BIT, XSA, HWH and ELF are one build."""
import hashlib
import json
import re
import zipfile
from pathlib import Path

design = Path(__file__).resolve().parents[1]
artifacts = design / "dma_gemm_board_probe" / "artifacts"
names = [f"zcu104_dma_gemm_board_probe.{ext}"
         for ext in ("bit", "xsa", "hwh", "elf")]
names += ["psu_init.tcl", "run_on_zcu104.tcl"]
sha = lambda data: hashlib.sha256(data).hexdigest()
file_hashes = {name: sha((artifacts / name).read_bytes()) for name in names}
expected_hashes = "".join(f"{file_hashes[name]}  {name}\n" for name in names)
assert (artifacts / "SHA256SUMS").read_text() == expected_hashes
with zipfile.ZipFile(artifacts / names[1]) as xsa:
    assert xsa.testzip() is None
    assert sha(xsa.read(names[0])) == file_hashes[names[0]]
    assert sha(xsa.read("system.hwh")) == file_hashes[names[2]]
    assert sha(xsa.read("psu_init.tcl")) == file_hashes["psu_init.tcl"]

timing = (artifacts / "routed_timing_summary.rpt").read_text()
match = re.search(
    r"WNS\(ns\).*?\n\s*-+.*?\n\s*([-\d.]+)\s+[-\d.]+\s+\d+\s+\d+\s+([-\d.]+).*?\s+([-\d.]+)\s+[-\d.]+\s+\d+\s+\d+\s*\n",
    timing, re.S)
assert match, "Timing summary not found"
wns, whs, wpws = map(float, match.groups())
assert min(wns, whs, wpws) >= 0.0, (wns, whs, wpws)
assert "All user specified timing constraints are met." in timing
assert "rsp_bridge_mid" in timing, "Response bridge placement constraint not evident in routed paths"
clock = re.search(r"^clk_pl_0\s+\{[^}]+\}\s+([\d.]+)\s+([\d.]+)\s*$", timing, re.M)
assert clock, "PL clock is missing from routed timing report"
clock_period_ns, actual_clock_mhz = map(float, clock.groups())
assert 6.65 < clock_period_ns < 6.68, clock_period_ns
assert 149.5 < actual_clock_mhz < 150.5, actual_clock_mhz

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

simulation = {}
for label, evidence_dir, marker in (
    ("gemm_wide_prefill_decode", "smollm2_gemm_systolic_wide_executor",
     "PASS smollm2_gemm_systolic_wide_executor"),
    ("gemm_wide_bank_integration", "smollm2_gemm_wide_bank_integration",
     "PASS smollm2_gemm_wide_bank_integration"),
    ("dma_load_gpio_b2_gemm_1x1", "smollm2_dma_gemm_board_probe",
     "PASS smollm2_dma_gemm_board_probe"),
):
    log = design / "evidence" / evidence_dir / "run_001/xsim.log"
    assert marker in log.read_text(), log
    simulation[label] = "PASS"

board_evidence = (design / "evidence/smollm2_dma_gemm_board_probe"
                  / "board_150mhz/run_001/user_uart_report.json")
physical_board = "not yet run; awaiting user UART log"
if board_evidence.is_file():
    reported = json.loads(board_evidence.read_text())
    assert reported["checkpoint_revision"] == "93efa2f097d58c2a74874c7e644dbc9b0cee75a2"
    assert reported["bit_sha256_at_handoff"] == file_hashes[names[0]]
    assert reported["elf_sha256_at_handoff"] == file_hashes[names[3]]
    checks = reported["checks"]
    assert checks["board_result"] == "PASS"
    assert checks["prefill_compared"] == 512 and checks["prefill_mismatches"] == 0
    assert checks["decode_compared"] == 16 and checks["decode_mismatches"] == 0
    physical_board = {
        "status": "user-reported PASS",
        "evidence": str(board_evidence.relative_to(design)),
        "host_hash_output_received": reported["host_hash_output_received"],
        "scope": reported["scope"],
        "limitation": reported["limitation"]
    }

record = {
    "checkpoint_revision": "93efa2f097d58c2a74874c7e644dbc9b0cee75a2",
    "device": "xczu7ev-ffvc1156-2-e",
    "tool_version": "Vivado/Vitis 2025.2",
    "app_bsp_provenance": "Vitis 2025.2 A53 standalone BSP from prior ZCU104 GEMM platform; app compiled against it because new platform generator stalled. New BIT/HWH/psu_init are from this XSA.",
    "pl_clock_mhz": actual_clock_mhz,
    "scope": "DDR MM2S DMA_LOAD B0/B3, GPIO B2 fill, PL GEMM B4 accepted-write tap, prefill/decode",
    "routed_setup_wns_ns": wns,
    "routed_hold_whs_ns": whs,
    "routed_pulse_wpws_ns": wpws,
    "routed_resources": resources,
    "artifact_sha256": file_hashes,
    "source_sha256": {
        name: sha((design / name).read_bytes()) for name in (
            "rtl/smollm2_dma_gemm_board_probe.sv",
            "rtl/smollm2_dma_gemm_board_probe_bd.v",
            "rtl/smollm2_gemm_dma_fabric_wide.sv",
            "rtl/smollm2_gemm_systolic_wide_executor.sv",
            "tb/tb_smollm2_dma_gemm_board_probe.sv",
            "scripts/create_dma_gemm_board_probe.tcl",
            "scripts/dma_gemm_rsp_bridge_floorplan.xdc",
            "dma_gemm_board_probe/main.c", "dma_gemm_board_probe/vectors.h")
    },
    "simulation": simulation,
    "physical_board": physical_board
}
(artifacts / "verification.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
