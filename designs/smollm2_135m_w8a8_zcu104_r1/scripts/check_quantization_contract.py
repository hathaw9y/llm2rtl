"""Validate approved quantization packet identities; no RTL or hardware claim."""
import hashlib
import json
from pathlib import Path


def check():
    design = Path(__file__).resolve().parents[1]
    root = design.parents[1]
    manifest = json.loads((design / "contracts/quantization_module_manifest.json").read_text())
    assert manifest["status"] == "frozen"
    for name, reference in manifest["refs"].items():
        source = root / reference["path"]
        assert hashlib.sha256(source.read_bytes()).hexdigest() == reference["sha256"], name
    module = json.loads((design / "modules/quantization_executor.json").read_text())
    binding = json.loads((design / "contracts/quantization_rtl_port_binding.json").read_text())
    arithmetic = json.loads((design / "contracts/datapaths/quantization_arithmetic.json").read_text())
    approval = json.loads((design / "contracts/quantization_implementation_approval.json").read_text())
    for reference in module["common_contracts"].values():
        source = root / reference["path"]
        assert hashlib.sha256(source.read_bytes()).hexdigest() == reference["sha256"], reference["path"]
    assert module["status"] == binding["status"] == arithmetic["status"] == "frozen"
    assert module["implemented_opcodes"] == ["QUANTIZE", "DEQUANTIZE"]
    assert approval["actual_user_reply"] == "그래"
    assert binding["executor"]["rtl_module"] == "smollm2_quantization_executor"
    assert binding["executor"]["descriptor_inputs"]["cmd_embedding_lanes"] == 64
    assert binding["executor"]["descriptor_inputs"]["cmd_embedding_lane_valid"] == 32
    assert binding["executor"]["descriptor_inputs"]["cmd_b7_static_valid"] == 1
    assert binding["local_buffers"]["full_tensor_buffer"] is False
    units = arithmetic["units"]
    for name, latency in [("w8a8_fp32_div4", 19), ("w8a8_quant_lane4", 22), ("w8a8_dequant_lane4", 8)]:
        assert units[name]["latency"] == latency
        assert units[name]["II"] == 1
    assert units["w8a8_quant_lane4"]["outputs"]["m_quotient"] == 128
    return {"status": "PASS_APPROVAL_CONTRACT_IDENTITY_ONLY", "module": module["module_id"],
            "manifest_sha256": hashlib.sha256((design / "contracts/quantization_module_manifest.json").read_bytes()).hexdigest(),
            "RTL_functional_synthesis_board": "requires_separate_evidence"}


if __name__ == "__main__":
    print(json.dumps(check(), indent=2))
