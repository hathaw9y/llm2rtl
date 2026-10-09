#!/usr/bin/env python3
"""Record scoped evidence for the 256-bit GEMM source-bank path."""
import hashlib
import json
import re
from pathlib import Path

design = Path(__file__).resolve().parents[1]
root = design.parents[1]
evidence = design / "evidence"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def result_text(module, name):
    return (evidence / module / "run_001" / name).read_text()


def resource(report, label):
    match = re.search(rf"(?m)^\|\s*{re.escape(label)}\s*\|\s*(\d+)", report)
    assert match, label
    return int(match.group(1))


def wns(report):
    match = re.search(r"(?m)^Setup\s*:\s*0\s+Failing Endpoints,\s*Worst Slack\s+([\d.]+)ns", report)
    assert match
    return float(match.group(1))


def main():
    tests = {
        "striped_xpm_bank": "smollm2_bank_memories_wide",
        "ownership_and_router": "smollm2_bank_subsystem_wide",
        "dma_control_fabric": "smollm2_dma_control_fabric_wide",
        "wide_gemm_checkpoint": "smollm2_gemm_systolic_wide_executor",
        "gemm_xpm_bank_connection": "smollm2_gemm_wide_bank_integration",
    }
    logs = {key: result_text(module, "xsim.log") for key, module in tests.items()}
    for key, module in tests.items():
        assert f"PASS {module}" in logs[key], key
    cycles = {key: int(value) for key, value in
              re.findall(r"CYCLES ([a-z0-9_]+)=(\d+)", logs["wide_gemm_checkpoint"])}
    assert cycles["full_m32_n192_k576"] == 162841
    reports = {}
    for key, module in (("gemm", "smollm2_gemm_systolic_wide_executor"),
                        ("fabric", "smollm2_dma_control_fabric_wide")):
        util = result_text(module, "utilization_post_synth.rpt")
        timing = result_text(module, "timing_post_synth.rpt")
        drc = result_text(module, "drc_post_synth.rpt")
        assert "| Error" not in drc
        reports[key] = {
            "lut": resource(util, "CLB LUTs*"),
            "ff": resource(util, "CLB Registers"),
            "dsp": resource(util, "DSPs"),
            "bram_tiles": resource(util, "Block RAM Tile"),
            "uram": resource(util, "URAM"),
            "wns_at_5ns": wns(timing),
            "synth_dcp_sha256": sha(evidence / module / "run_001" /
                                      f"{module}_synth.dcp"),
        }
    source_paths = [
        "bank_layout.json", "isa_spec.json", "isa_validation.json",
        "bank_wide_read_design.md",
        "modules/gemm_systolic_wide_executor.json",
        "modules/smollm2_bank_memories_wide.json",
        "modules/smollm2_bank_subsystem_wide.json",
        "modules/smollm2_dma_control_fabric_wide.json",
        "rtl/smollm2_gemm_systolic_wide_executor.sv",
        "rtl/smollm2_bank_memories_wide.sv",
        "rtl/smollm2_bank_port_router_wide.sv",
        "rtl/smollm2_bank_subsystem_wide.sv",
        "rtl/smollm2_dma_control_fabric_wide.sv",
        "tb/tb_smollm2_gemm_systolic_wide_executor.sv",
        "tb/tb_smollm2_bank_memories_wide.sv",
        "tb/tb_smollm2_bank_subsystem_wide.sv",
        "tb/tb_smollm2_dma_control_fabric_wide.sv",
        "tb/tb_smollm2_gemm_wide_bank_integration.sv",
        "scripts/run_gemm_systolic_wide_xsim.sh",
        "scripts/run_gemm_systolic_wide_ooc.tcl",
        "scripts/run_bank_memories_wide_xsim.sh",
        "scripts/run_bank_subsystem_wide_xsim.sh",
        "scripts/run_dma_control_fabric_wide_xsim.sh",
        "scripts/run_dma_control_fabric_wide_ooc.tcl",
        "scripts/run_gemm_wide_bank_integration_xsim.sh",
        "scripts/write_wide_read_evidence.py",
    ]
    report = {
        "design_id": "smollm2_135m_bf16_zcu104",
        "revision": "r1",
        "change": "B2/B3/B10/B11 paired 256-bit GEMM source reads; 128-bit writes and other role reads retained",
        "source_sha256": {str((design / x).relative_to(root)): sha(design / x)
                          for x in source_paths},
        "reused_source_sha256": {
            x: sha(root / x) for x in (
                "ip/infrastructure/datamover_engine/rtl/bram_bank.sv",
                "ip/infrastructure/datamover_engine/rtl/uram_bank.sv",
                "ip/infrastructure/bank_ownership_table/rtl/bank_ownership_table.sv",
                "designs/smollm2_135m_bf16_zcu104_r1/rtl/smollm2_dma_bank_bridge.sv",
                "designs/smollm2_135m_bf16_zcu104_r1/rtl/smollm2_dma_engine_link.sv",
            )
        },
        "checks": {key: "PASS, XSIM 2025.2" for key in tests},
        "selected_checkpoint_outputs": "528/528 bitwise equal in standalone wide GEMM test",
        "ooc_vivado_version": "2025.2",
        "standalone_ooc": reports,
        "full_m32_n192_k576_no_stall_cycles": {
            "128_bit_read": 218137, "256_bit_read": cycles["full_m32_n192_k576"],
            "reduction_percent": round((1 - cycles["full_m32_n192_k576"] / 218137) * 100, 2),
            "not_board_throughput": True,
        },
        "limitations": [
            "GEMM and DMA control fabric were synthesized separately; their sum is not a placed/routed integration result.",
            "The bank/GEMM integration XSIM covers one real XPM result path, not all model opcodes.",
            "Full-model numerical output, vendor DataMover IP, DDR, Vitis software and physical board execution remain unverified.",
        ],
    }
    target = evidence / "wide_read_integration" / "run_001" / "module_verification_report.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"report": str(target), "ooc": reports,
                      "cycles": cycles["full_m32_n192_k576"]}))


if __name__ == "__main__":
    main()
