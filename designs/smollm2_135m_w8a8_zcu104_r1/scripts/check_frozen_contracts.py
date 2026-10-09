"""Scoped frozen-contract checks; deliberately not an ISA tensor PASS."""
import hashlib
import json
from pathlib import Path


def read(path):
    def unique(pairs):
        result = {}
        for k, v in pairs:
            if k in result:
                raise ValueError(f"duplicate key {k}: {path}")
            result[k] = v
        return result
    return json.loads(path.read_text(), object_pairs_hook=unique)


def check():
    design = Path(__file__).resolve().parents[1]
    root = design.parents[1]
    manifest = read(design / "contracts/manifest.json")
    isa = read(design / "isa_spec.json")
    banks = read(design / "bank_layout.json")
    numeric = read(design / "contracts/numeric_contract.json")
    interface = read(design / "contracts/compute_interface.json")
    for name, digest in manifest["contract_files"].items():
        assert hashlib.sha256((design / name).read_bytes()).hexdigest() == digest, name
    for path, digest in isa["common_contracts"].items():
        assert hashlib.sha256((root / path).read_bytes()).hexdigest() == digest, path
    for doc in [isa, banks, numeric, interface]:
        assert doc["design_id"] == manifest["design_id"]
        assert doc["revision"] == manifest["revision"]
    assert isa["status"] == "reviewed" and isa["unresolved_decisions"] == []
    assert len(isa["opcodes"]) == 15
    codes = [op["encoding"] for op in isa["opcodes"]]
    assert len(set(codes)) == 15 and 12 not in codes
    for layout in isa["instruction_record"]["payload_formats"].values():
        bits = set()
        for high, low in layout.values():
            assert 0 <= low <= high < 112
            occupied = set(range(low, high+1))
            assert not occupied & bits
            bits |= occupied
    assert [b["encoded_id"] for b in banks["banks"]] == list(range(16))
    for bank in banks["banks"]:
        assert bank["capacity_words"]*bank["word_bits"]//8 == bank["capacity_bytes"]
        assert bank["capacity_bytes"] % 32 == 0
        if bank["scale_region_byte_offset"] is not None:
            assert bank["scale_region_byte_offset"] % 32 == 0
            assert bank["scale_region_byte_offset"]+bank["scale_region_capacity_bytes"] <= bank["capacity_bytes"]
        assert bank["profile_codes"] == [isa["profile_encodings"][x] for x in bank["allowed_profiles"]]
    assert banks["logical_capacity_bytes"] == sum(b["capacity_bytes"] for b in banks["banks"])
    b7 = banks["banks"][7]
    assert b7["components"]["RoPE_window"]["capacity_bytes"] == 4096
    assert b7["components"]["static_KV_scales"]["byte_offset"] == 4096
    assert b7["capacity_bytes"] == 6016
    assert banks["banks"][3]["scale_region_capacity_bytes"] >= 32*16
    assert numeric["agreed"]["accumulator_runtime_overflow_detection"] is False
    assert interface["integer_overflow_error"] == "No runtime detector or error code"
    assert max(interface["roles"].values()) < 32
    validation = read(design / "isa_validation.json")
    assert validation["status"] == "pending_tensor_interpreter"
    for key in ["model_trace", "isa_spec", "bank_layout"]:
        ref = validation[key]
        assert hashlib.sha256((root / ref["path"]).read_bytes()).hexdigest() == ref["sha256"]
    return {"status": "passed_frozen_contract_structure_and_identity_only",
            "contract_files": manifest["contract_files"], "bank_count": 16,
            "opcode_count": 15, "logical_bank_capacity_bytes": banks["logical_capacity_bytes"],
            "tensor_validation": "pending", "RTL_synthesis_board_quality": "not_verified"}


if __name__ == "__main__":
    print(json.dumps(check(), indent=2))
