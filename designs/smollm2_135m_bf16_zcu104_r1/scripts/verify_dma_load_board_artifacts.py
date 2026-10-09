#!/usr/bin/env python3
"""Check that the routed DMA probe BIT, XSA, HWH and ELF are one build."""
import hashlib
import json
import re
import zipfile
from pathlib import Path

design = Path(__file__).resolve().parents[1]
artifacts = design / "dma_load_board_probe" / "artifacts"
names = [f"zcu104_dma_load_board_probe.{ext}"
         for ext in ("bit", "xsa", "hwh", "elf")]
sha = lambda data: hashlib.sha256(data).hexdigest()
file_hashes = {name: sha((artifacts / name).read_bytes()) for name in names}
with zipfile.ZipFile(artifacts / names[1]) as xsa:
    assert xsa.testzip() is None
    assert sha(xsa.read(names[0])) == file_hashes[names[0]]
    assert sha(xsa.read("system.hwh")) == file_hashes[names[2]]
    assert "psu_init.tcl" in xsa.namelist()

timing = (artifacts / "routed_timing_summary.rpt").read_text()
match = re.search(
    r"WNS\(ns\).*?\n\s*-+.*?\n\s*([-\d.]+)\s+[-\d.]+\s+\d+\s+\d+\s+([-\d.]+).*?\s+([-\d.]+)\s+[-\d.]+\s+\d+\s+\d+\s*\n",
    timing, re.S)
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

board_log = design / "evidence/smollm2_dma_load_board_probe/run_001/user_uart.log"
physical_board = "not yet run; awaiting user UART log"
if board_log.is_file():
    lines = board_log.read_text().splitlines()
    expected = [
        "SmolLM2-135M BF16 ZCU104 DDR DMA_LOAD probe",
        "checkpoint 93efa2f097d58c2a74874c7e644dbc9b0cee75a2",
        "BANK 0 compare=18432 mismatches=0",
        "BANK 3 compare=9216 mismatches=0",
        "CHUNK prefill DONE",
        "BANK 0 compare=576 mismatches=0",
        "BANK 3 compare=9216 mismatches=0",
        "CHUNK decode DONE",
        "BOARD DMA_LOAD PASS",
    ]
    assert lines == expected, "Unexpected physical-board UART log"
    physical_board = {
        "status": "user_reported_PASS",
        "scope": "DDR MM2S DMA_LOAD BF16 bit-exact readback for B0/B3, prefill/decode, and B3 retention",
        "uart_log": str(board_log.relative_to(design)),
        "uart_log_sha256": sha(board_log.read_bytes()),
        "identity_limit": "UART log identifies the checkpoint but does not independently attest the host BIT/ELF hashes",
    }

record = {
    "checkpoint_revision": "93efa2f097d58c2a74874c7e644dbc9b0cee75a2",
    "device": "xczu7ev-ffvc1156-2-e",
    "tool_version": "Vivado/Vitis 2025.2",
    "app_bsp_provenance": "Vitis 2025.2 A53 standalone BSP from prior ZCU104 GEMM platform; app compiled against it because new platform generator stalled. New BIT/HWH/psu_init are from this XSA.",
    "pl_clock_mhz": 200,
    "scope": "DDR MM2S DMA_LOAD to B0 and B3, BF16 readback, prefill/decode chunks",
    "routed_setup_wns_ns": wns,
    "routed_hold_whs_ns": whs,
    "routed_pulse_wpws_ns": wpws,
    "routed_resources": resources,
    "artifact_sha256": file_hashes,
    "source_sha256": {
        name: sha((design / name).read_bytes()) for name in (
            "rtl/smollm2_dma_load_board_probe.sv",
            "rtl/smollm2_dma_load_board_probe_bd.v",
            "dma_load_board_probe/main.c", "dma_load_board_probe/vectors.h")
    },
    "simulation": {
        "isa_dma_load_bf16_banks": "PASS",
        "board_probe_control": "PASS"
    },
    "physical_board": physical_board
}
(artifacts / "verification.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
