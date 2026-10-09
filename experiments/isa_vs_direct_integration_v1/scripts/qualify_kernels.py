#!/usr/bin/env python3
"""Fresh standalone replay in separate storage; never writes original design."""
import argparse
import datetime
import hashlib
import json
import os
import shutil
import subprocess
import time
from pathlib import Path

from inventory_kernels import FILES, REPO, STUDY

DESIGN = REPO / "designs/smollm2_135m_bf16_zcu104_r1"
VIVADO = Path("/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    kernels = out / "kernels"
    kernels.mkdir()
    identities = {}
    for name in FILES:
        src = DESIGN / "rtl" / name
        shutil.copy2(src, kernels / name)
        identities[name] = sha(src)
    report = {
        "stage": "RUNNING", "scope": "fresh standalone replay only",
        "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "source_sha256": identities, "tests": [],
        "integration_evaluator_qualified": False,
    }
    started = time.monotonic()
    env = dict(os.environ)
    env["PATH"] = str(VIVADO) + os.pathsep + env.get("PATH", "")

    def save():
        report["elapsed_seconds"] = time.monotonic() - started
        (out / "report.json").write_text(json.dumps(report, indent=2) + "\n")

    def command(argv, cwd, log, timeout=600):
        with (cwd / log).open("w") as stream:
            result = subprocess.run(argv, cwd=cwd, env=env, stdout=stream,
                                    stderr=subprocess.STDOUT, timeout=timeout)
        raw = (cwd / log).read_text(errors="replace")
        if result.returncode or "FATAL" in raw or "ERROR:" in raw:
            raise RuntimeError(f"{log}: exit={result.returncode}; inspect {cwd / log}")
        return raw

    specs = [
        ("rmsnorm", "smollm2_rmsnorm_executor", []),
        ("rope", "smollm2_rope_executor", []),
        ("gemm", "smollm2_gemm_systolic_wide_executor",
         ["gemm_executor", "gemm_model", "gemm_systolic_model"]),
        ("softmax", "smollm2_softmax_executor", ["softmax_checkpoint"]),
        ("silu_mul", "smollm2_silu_mul_executor", ["silu_mul_checkpoint"]),
        ("add", "smollm2_add_executor", ["add_checkpoint"]),
    ]
    save()
    for label, module, fixture_names in specs:
        entry = {"kernel": label, "status": "RUNNING", "runs": []}
        report["tests"].append(entry)
        save()
        work = out / label
        work.mkdir()
        top = "tb_" + module
        tb = DESIGN / "tb" / (top + ".sv")
        shutil.copy2(tb, work / tb.name)
        entry["testbench_sha256"] = sha(tb)
        fixture_records = []
        for folder in fixture_names:
            for path in sorted((DESIGN / "golden" / folder).glob("*.hex")):
                target = work / path.name if label == "gemm" else work / "vectors" / path.name
                target.parent.mkdir(exist_ok=True)
                shutil.copy2(path, target)
                fixture_records.append({"file": str(path.relative_to(DESIGN)), "sha256": sha(path)})
        if label == "silu_mul":
            shutil.copy2(kernels / "smollm2_silu_bf16_lut.mem", work / "smollm2_silu_bf16_lut.mem")
        try:
            if label == "gemm":
                command([str(VIVADO / "xvlog"), "-sv", str(kernels / (module + ".sv")),
                         str(work / tb.name)], work, "compile.log")
                command([str(VIVADO / "xelab"), top, "--timescale", "1ns/1ps", "-s", "kernel_sim"],
                        work, "elaborate.log")
                runner = REPO / "ip/infrastructure/datamover_engine/scripts/run_xsimk.py"
                raw = command(["python3", str(runner), str(work / "xsim.dir/kernel_sim/xsimk"),
                               "PASS " + module], work, "run.log")
                if "PASS " + module not in raw:
                    raise RuntimeError("missing final GEMM PASS marker")
                entry["runs"].append({"name": "standalone", "status": "PASS"})
            else:
                command(["iverilog", "-g2012", "-I", str(kernels), "-s", top,
                         "-o", "kernel.vvp", str(kernels / (module + ".sv")), str(work / tb.name)],
                        work, "compile.log")
                runs = [("standalone", [])]
                if label == "rope":
                    runs = []
                    for case, rows in [("prefill", 32), ("decode", 1), ("prefill_tail", 32)]:
                        fixture = DESIGN / "golden/rope_checkpoint" / case
                        shutil.copytree(fixture, work / case)
                        for path in sorted(fixture.glob("*.hex")):
                            fixture_records.append({"file": str(path.relative_to(DESIGN)), "sha256": sha(path)})
                        for kind in ["q", "k"]:
                            runs.append((case + "_" + kind,
                                         ["+CASE=" + case, "+KIND=" + kind, "+ROWS=" + str(rows)]))
                    for negative in ["zero_rows", "too_many_rows", "wrong_bank", "nan_input"]:
                        runs.append((negative, ["+CASE=decode", "+KIND=q", "+ROWS=1", "+NEGATIVE=" + negative]))
                for name, plusargs in runs:
                    raw = command(["vvp", "kernel.vvp", *plusargs], work, name + ".log")
                    if "PASS" not in raw or "Unable to open" in raw:
                        raise RuntimeError("missing PASS or unavailable fixture: " + name)
                    entry["runs"].append({"name": name, "status": "PASS"})
            entry["status"] = "PASS"
        except Exception as exc:
            entry["status"] = "FAIL"
            entry["error"] = str(exc)
        entry["fixtures"] = fixture_records
        save()
        print(label, entry["status"], flush=True)
    report["source_unchanged"] = all(sha(DESIGN / "rtl" / name) == value for name, value in identities.items())
    report["stage"] = "PASS" if report["source_unchanged"] and all(t["status"] == "PASS" for t in report["tests"]) else "FAIL"
    save()
    print("FRESH_KERNEL_REPLAY", report["stage"], flush=True)


if __name__ == "__main__":
    main()
