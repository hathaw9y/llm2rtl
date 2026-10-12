#!/usr/bin/env python3
"""Render and self-check reference authoring templates; no model/board signoff."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

from infrastructure_sources import ROOT, resolve_profile, resolve_reference
from run_infrastructure_sim import decoded_xsim

FIXTURE = ROOT / "verification/infrastructure/reference_templates_20261012"
INFRA = ROOT / "ip/infrastructure"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def save(path, data):
    Path(path).write_text(json.dumps(data, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="fresh evidence directory")
    parser.add_argument("--vivado-bin", type=Path, default=Path("/tools/Xilinx/2025.2/Vivado/bin"))
    parser.add_argument("--include-compatibility", action="store_true",
                        help="required: this runner exercises retired generic templates only")
    args = parser.parse_args()
    if not args.include_compatibility:
        parser.error("retired template fixture requires --include-compatibility; current references use original source RTL")
    out = args.out.expanduser().resolve()
    if out.exists():
        parser.error("fresh output directory required")
    out.mkdir(parents=True)
    env = os.environ.copy()
    env["XILINX_VIVADO"] = str(args.vivado_bin.resolve().parent)
    started = time.monotonic()
    report = {"schema": "llm2rtl.reference_template_fixture.v1", "status": "running",
        "started_utc": datetime.now(timezone.utc).isoformat(), "scope": "archived generic template control fixture; not current design references",
        "compatibility_included": True,
        "real_native_bank_ownership": True, "real_core_datapath": False,
        "native_memory_traffic_exercised": False, "sources": [], "cases": [], "lint": [],
        "does_not_claim": ["model execution", "numerical kernel correctness", "reference ISA binary compatibility",
            "OOC synthesis", "timing closure", "resource mapping", "board runtime", "DDR/DMA implementation"]}
    snapshots = {}

    def capture(path):
        path = Path(path).resolve()
        if str(path) in snapshots:
            return
        relative = Path("generated") / path.relative_to(out) if path.is_relative_to(out) else path.relative_to(ROOT)
        snapshot = out / "source_snapshot" / relative
        snapshot.parent.mkdir(parents=True, exist_ok=True)
        snapshot.write_bytes(path.read_bytes())
        record = {"path": str(path), "sha256": sha(path), "snapshot": str(snapshot),
            "snapshot_sha256": sha(snapshot), "generated_fixture": path.is_relative_to(out)}
        snapshots[str(path)] = record
        report["sources"].append(record)

    def run(command, cwd, logfile, timeout=120):
        t0=time.monotonic()
        record={"command": [str(arg) for arg in command], "cwd": str(cwd), "log": str(logfile), "timeout_seconds": timeout}
        with logfile.open("x") as stream:
            proc=subprocess.Popen(record["command"], cwd=cwd, env=env, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                proc.wait(timeout=timeout)
                record["timeout"]=False
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL); proc.wait(); record["timeout"]=True
        record["exit_code"]=proc.returncode
        record["duration_seconds"]=time.monotonic()-t0
        return record

    try:
        originals = [Path(__file__).resolve(), ROOT / "scripts/infrastructure_sources.py",
            ROOT / "scripts/run_infrastructure_sim.py", INFRA / "scripts/run_xsimk.py",
            FIXTURE / "materialize.py", FIXTURE / "tb_reference_templates.sv"]
        originals += [resolve_reference("ip/infrastructure/templates/" + filename) for filename in
            ("controller.sv.tpl", "executor_engine.sv.tpl", "execution_fabric_native.sv.tpl",
                "bank_config_pkg.sv.tpl", "bank_subsystem.sv.tpl")]
        native = resolve_profile("native_bank_children", include_compatibility=True)
        for path in [*originals, *native]: capture(path)
        report["tool_version"] = run([args.vivado_bin / "vivado", "-version"], out, out / "vivado_version.log")
        spec=importlib.util.spec_from_file_location("reference_fixture_materialize", FIXTURE / "materialize.py")
        module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        for width, latency, denied in ((3,1,False),(3,3,False),(2,1,False),(2,3,False),(3,1,True)):
            work=out / (f"bankid{width}_readlat{latency}" + ("_denied_ack" if denied else ""))
            work.mkdir()
            case={"bank_id_width": width, "bank_num": 4, "read_latency": latency,
                "denied_native_capability": denied, "status": "running", "commands": []}
            case_started=time.monotonic()
            generated=module.materialize(work, width, denied)
            sources=[generated[0],*native,*generated[1:],FIXTURE / "tb_reference_templates.sv"]
            for path in generated: capture(path)
            commands=[([args.vivado_bin / "xvlog", "--sv", *sources], "compile.log"),
                ([args.vivado_bin / "xelab", "tb_reference_templates", "-L", "xpm", "-s", "template_fixture",
                    "-timescale", "1ns/1ps", "-generic_top", f"READ_LATENCY={latency}",
                    "-generic_top", f"ACK_FAILURE_CASE={int(denied)}"], "elaborate.log"),
                ([sys.executable, INFRA / "scripts/run_xsimk.py", work / "xsim.dir/template_fixture/xsimk",
                    "PASS reference templates context/ownership/stall/core-rearm/drain/END/error/reset"], "simulation.log")]
            for command, filename in commands:
                record=run(command, work, work / filename)
                case["commands"].append(record)
                if record["exit_code"] or record["timeout"]:
                    case["status"]="failed"
                    break
            if case["status"] != "failed":
                stdout=decoded_xsim((work / "simulation.log").read_text())
                (work / "simulation.stdout").write_text(stdout)
                passes=re.findall(r"^PASS reference templates context/ownership/stall/core-rearm/drain/END/error/reset checks=(\d+)$", stdout, re.M)
                case["checks"] = int(passes[0]) if len(passes)==1 else 0
                case["status"] = "passed" if len(passes)==1 and not re.search(r"\b(?:FATAL|Fatal|ERROR)\b",stdout) else "failed"
            case["duration_seconds"]=time.monotonic()-case_started
            save(work / "result.json",case)
            report["cases"].append(case); save(out / "result.json",report)
            print(f"{case['status'].upper()} bank_id_width={width} read_latency={latency}", flush=True)
            if case["status"]=="failed":
                raise RuntimeError(f"template fixture failed at {work}")
        work=out / "bankid3_readlat1"
        for top in ("reference_test_controller", "reference_test_executor"):
            record=run(["verilator","--lint-only","-Wall","-Wno-fatal","--top-module",top,
                work / "reference_test_config_pkg.sv", work / f"{top}.sv"], work, out / f"lint_{top}.log")
            transcript=Path(record["log"]).read_text()
            record["warning_classes"]=sorted(set(re.findall(r"%Warning-([A-Z0-9_]+)",transcript)))
            record["warning_policy"]="Warnings are reported explicitly; lint is a template smoke check, not warning-clean signoff."
            report["lint"].append(record)
            if record["exit_code"] or record["timeout"]: raise RuntimeError(f"lint failed for {top}")
        report["input_integrity"] = all(sha(record["path"])==record["sha256"] and sha(record["snapshot"])==record["sha256"] for record in snapshots.values())
        if not report["input_integrity"]: raise RuntimeError("run input changed")
        report["status"]="passed"
    except Exception as error:
        report["status"]="failed"; report["error"]=f"{type(error).__name__}: {error}"
    finally:
        report["duration_seconds"]=time.monotonic()-started
        save(out / "result.json",report)
    return 0 if report["status"]=="passed" else 1


if __name__=="__main__":
    raise SystemExit(main())
