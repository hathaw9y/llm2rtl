"""Infrastructure packet identities only; no functional or hardware claim."""
import hashlib
import json
from pathlib import Path


def check():
    design = Path(__file__).resolve().parents[1]
    root = design.parents[1]
    binding_path = design / "contracts/infrastructure_rtl_port_binding.json"
    binding_digest = hashlib.sha256(binding_path.read_bytes()).hexdigest()
    binding = json.loads(binding_path.read_text())
    assert binding["status"] == "frozen"
    assert binding["clock_ns"] == 5.0
    assert binding["part"] == "xczu7ev-ffvc1156-2-e"
    assert len(binding["engine_slots"]) == 4
    results = {}
    for module in ("isa_dispatcher", "bank_controller"):
        path = design / "contracts" / (module + "_module_manifest.json")
        manifest = json.loads(path.read_text())
        assert manifest["status"] == "frozen"
        assert manifest["module_id"] == module
        for name, reference in manifest["refs"].items():
            source = root / reference["path"]
            assert hashlib.sha256(source.read_bytes()).hexdigest() == reference["sha256"], (module, name)
        results[module] = hashlib.sha256(path.read_bytes()).hexdigest()
    clarification = json.loads((design / "contracts/infrastructure_boundary_clarifications.json").read_text())
    assert clarification["binding_sha256"] == binding_digest
    assert clarification["binding_revision"] == binding["binding_revision"] == 2
    assert binding["invalidate"]["inputs"]["invalidate_component"] == 2
    return {"status": "PASS_FROZEN_INFRASTRUCTURE_IDENTITIES_ONLY", "modules": results,
            "binding_sha256": binding_digest, "functional_synthesis_integration": "requires separate exact-source evidence"}


if __name__ == "__main__":
    print(json.dumps(check(), indent=2))
