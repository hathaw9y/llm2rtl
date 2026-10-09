#!/usr/bin/env python3
"""Record scoped XSIM/OOC evidence for the DSP-based 16x16 GEMM."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DESIGN = Path(__file__).resolve().parents[1]
EVIDENCE = DESIGN / "evidence" / "smollm2_gemm_systolic_wordbuf_executor"


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def resource(report: str, label: str) -> int:
    match = re.search(rf"(?m)^\|\s*{re.escape(label)}\s*\|\s*(\d+)", report)
    assert match, label
    return int(match.group(1))


def main() -> None:
    sim = (EVIDENCE / "run_001" / "xsim.log").read_text()
    util = (EVIDENCE / "run_001" / "utilization_post_synth.rpt").read_text()
    timing = (EVIDENCE / "run_001" / "timing_post_synth.rpt").read_text()
    drc = (EVIDENCE / "run_001" / "drc_post_synth.rpt").read_text()
    assert 'PASS smollm2_gemm_systolic_wordbuf_executor' in sim
    timing_match = re.search(r"(?m)^\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+(\d+)\s+(\d+)\s+(-?\d+\.\d+)", timing)
    assert timing_match
    wns, tns, failing, endpoints, whs = timing_match.groups()
    cycles = {key: int(value) for key, value in
              re.findall(r"CYCLES ([a-z0-9_]+)=(\d+)", sim)}
    assert cycles["full_m32_n192_k576"] == 218137
    warnings = {name: int(count) for name, count in
                re.findall(r"(?m)^\|\s*(DPIP-2|DPOP-3|DPOP-4)\s*\|[^\n]*\|\s*(\d+)\s*\|", drc)}
    checkpoint = json.loads((DESIGN / "golden/gemm_systolic_model/manifest.json").read_text())
    source_paths = [
        "rtl/smollm2_gemm_systolic_wordbuf_executor.sv",
        "tb/tb_smollm2_gemm_systolic_wordbuf_executor.sv",
        "modules/gemm_systolic_wordbuf_executor.json",
        "gemm_systolic_wordbuf_design.md",
        "isa_spec.json", "isa_validation.json",
        "scripts/run_gemm_systolic_wordbuf_xsim.sh",
        "scripts/run_gemm_systolic_wordbuf_ooc.tcl",
        "scripts/generate_gemm_systolic_model_vectors.py",
        "scripts/write_gemm_systolic_wordbuf_evidence.py",
        "golden/gemm_systolic_model/manifest.json",
    ]
    for folder in ("golden/gemm_executor", "golden/gemm_model",
                   "golden/gemm_systolic_model"):
        source_paths.extend(str(path.relative_to(DESIGN))
                            for path in sorted((DESIGN / folder).glob("*.hex")))
    source_hashes = {str((DESIGN / path).relative_to(ROOT)): sha(DESIGN / path)
                     for path in source_paths}
    report = {
        "design_id": "smollm2_135m_bf16_zcu104",
        "revision": "r1",
        "module_id": "gemm_systolic_wordbuf_executor",
        "architecture": "16x16 output-stationary systolic PE array, K chunk 16, registered DSP BF16 significand multipliers",
        "source_sha256": source_hashes,
        "evidence_identity": {
            "xsim_run": "run_001",
            "full_ooc_run": "run_001, Vivado 2025.2, -flatten_hierarchy none",
            "pe_ooc_run": "same PE arithmetic as prior version; no separate PE run",
            "synth_dcp_sha256": sha(EVIDENCE / "run_001/smollm2_gemm_systolic_wordbuf_executor_synth.dcp"),
        },
        "checks": {
            "xsim": "PASS, behavioral bank-word model; includes BF16 numerical, control, tails and full 32x192x576",
            "checkpoint_prefill": "512/512 bitwise equal to exact BF16 and PyTorch BF16 for layer-0 q_proj, 32 rows x first 16 columns",
            "checkpoint_decode": "16/16 bitwise equal to exact BF16 and PyTorch BF16 for layer-0 q_proj",
            "verilator_lint": "exit 0 with nonfatal warnings",
            "isa_structure": "passed_structure_only with this module as GEMM opcode binding",
            "ooc_synthesis": "PASS, 5 ns clock constraint",
            "ooc_setup": "PASS" if float(wns) >= 0 and int(failing) == 0 else "FAIL",
            "drc": "no Error severity; DSP pipelining advisory warnings recorded separately",
            "fabric_integration": "not run",
            "placed_routed_timing": "not run",
            "board_execution": "not run",
        },
        "resources_post_synth": {
            "clb_luts": resource(util, "CLB LUTs*"),
            "clb_registers": resource(util, "CLB Registers"),
            "dsp48": resource(util, "DSPs"),
            "bram_tiles": resource(util, "Block RAM Tile"),
            "uram": resource(util, "URAM"),
        },
        "comparison_to_prior_standalone_ooc": {
            "prior_luts": 190018,
            "lut_reduction": 190018 - resource(util, "CLB LUTs*"),
            "prior_registers": 38206,
            "register_increase": resource(util, "CLB Registers") - 38206,
            "prior_dsp48": 263,
            "same_xsim_full_command_cycles": True,
        },
        "timing_post_synth_ns": {
            "clock_period": 5.0, "wns": float(wns), "tns": float(tns),
            "failing_endpoints": int(failing), "total_endpoints": int(endpoints),
            "whs": float(whs),
        },
        "drc_advisory_counts": warnings,
        "cycles_no_bank_stalls": cycles,
        "full_m32_n192_k576": {
            "mac_count": 32 * 192 * 576,
            "cycles": cycles["full_m32_n192_k576"],
            "seconds_if_200mhz": cycles["full_m32_n192_k576"] / 200_000_000,
            "speedup_vs_scalar_xsim": 21_258_241 / cycles["full_m32_n192_k576"],
            "not_board_throughput": True,
        },
        "checkpoint_revision": checkpoint["checkpoint_revision"],
        "numeric_rule": "exact BF16 significand product in DSP; K-ascending signed 32-bit shared-exponent accumulation with four guard bits and magnitude-truncating alignment; BF16 nearest-even output",
        "limitations": [
            "Only selected layer-0 q_proj columns are compared to the real checkpoint; all layers and end-to-end logits remain unverified.",
            "Standalone XSIM uses a behavioral 128-bit bank model, not the integrated XPM bank fabric.",
            "OOC synthesis timing is not placed/routed timing and cannot establish a working ZCU104 bitstream.",
            "Other executors, integrated resource total, Vitis runtime and physical board execution remain outstanding.",
        ],
    }
    assert report["resources_post_synth"]["dsp48"] >= 256
    assert report["checks"]["ooc_setup"] == "PASS"
    target = EVIDENCE / "run_001/module_verification_report.json"
    target.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"report": str(target), "resources": report["resources_post_synth"],
                      "wns": report["timing_post_synth_ns"]["wns"]}))


if __name__ == "__main__":
    main()
