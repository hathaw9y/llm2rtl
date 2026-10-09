"""Execute new test fixtures through the pinned ISA tensor interpreter."""
import hashlib
import json
from pathlib import Path

from isa_codec import decode
from isa_interpreter import Interpreter

D = Path(__file__).resolve().parents[1]


def raw(path):
    return b"".join(int(line, 16).to_bytes(16, "little")
                    for line in path.read_text().splitlines())


def check():
    path = D / "tb/quant_executor_vectors/manifest.json"
    manifest = json.loads(path.read_text())
    results = []
    for item in manifest["cases"]:
        folder = D / item["path"]
        case = json.loads((folder / "case.json").read_text())
        command = decode(int(case["hex128"], 16))
        static = command["opcode"] == "QUANTIZE" and command["fields"]["mode"] in (2, 3)
        vm = Interpreter()
        for slot, bank_meta in enumerate(case["banks"]):
            if slot == 1 and not static:
                continue
            bank = vm.banks[bank_meta["bank"]]
            desc = bank_meta["descriptor"]
            image = raw(folder / bank_meta["initial_file"])
            if slot == 2:
                bank.data[:] = image
                bank.generations[0] = desc["generation"]
                continue
            fields = {key: desc[key] for key in ["profile", "rows", "cols", "position", "layer", "generation"]}
            fields["component"] = 0
            try:
                bank.configure(fields)
            except Exception as error:
                raise ValueError(f"{case['name']} slot{slot}: {error}") from error
            bank.data[:] = image
            for key, (lo, hi) in bank.ranges.items():
                if bank.index == 7 and key == "rope":
                    continue
                bank.coverage[lo:hi] = bytes([1]) * (hi - lo)
            if command["opcode"] == "DEQUANTIZE":
                bank.lanes = {int(row): int(lane) for row, lane in case["embedding_lanes"].items()}
        vm.execute(command["opcode"], command["banks"], command["fields"])
        actual = bytes(vm.banks[command["banks"][2]].data)
        expected = raw(folder / case["expected_file"])
        assert actual == expected, case["name"]
        results.append({"case": case["name"], "status": "PASS_PINNED_INTERPRETER_FULL_C_ALLOCATION"})
    report = {"scope": "Test-only pinned ISA interpreter replay; not RTL or hardware evidence",
              "manifest_sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "cases": results}
    (D / "evidence/quantization_fixture_reference_check.json").write_text(json.dumps(report, indent=2) + "\n")
    return {"status": "PASS", "cases": len(results)}


if __name__ == "__main__":
    print(json.dumps(check(), indent=2))
