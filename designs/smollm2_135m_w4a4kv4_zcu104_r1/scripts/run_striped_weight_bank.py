#!/usr/bin/env python3
"""Fresh-output, source-bound XPM verification and real-depth Vivado OOC runner."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from striped_bank_reference import generate

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
sys.path.insert(0, str(REPO / "scripts"))
from infrastructure_sources import resolve_reference

LEAF = ROOT / "rtl/smollm2_striped_weight_bank.sv"
TB = ROOT / "tb/tb_smollm2_striped_weight_bank.sv"
URAM = REPO / "ip/infrastructure/bank/uram_bank.sv"
XPM = Path('/tools/Xilinx/2025.2/Vivado/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv')
CONTRACT = ROOT / "contracts/striped_weight_bank_contract.json"
EXPECTED_CONTRACT_HASH = "f9da1cfbf1564a0602e3caf9aef4b573181525a73d7e888dfc9fe6261f850468"
PASS_MARKER = 'PASS: smollm2 striped bank XPM functional verification'
CASES = [dict(name="ports4_lat3", PORT_COUNT=4, READ_LATENCY=3, ADDR_WIDTH=32),
         dict(name="ports4_lat2", PORT_COUNT=4, READ_LATENCY=2, ADDR_WIDTH=32),
         dict(name="ports3_lat3", PORT_COUNT=3, READ_LATENCY=3, ADDR_WIDTH=32),
         dict(name="ports1_lat2", PORT_COUNT=1, READ_LATENCY=2, ADDR_WIDTH=32),
         dict(name="full_address_space4_lat3", PORT_COUNT=4, READ_LATENCY=3, ADDR_WIDTH=4),
         dict(name="full_address_space3_lat2", PORT_COUNT=3, READ_LATENCY=2, ADDR_WIDTH=4),
         dict(name="ports4_lat1", PORT_COUNT=4, READ_LATENCY=1, ADDR_WIDTH=32),
         dict(name="illegal_address_width", PORT_COUNT=4, READ_LATENCY=3, ADDR_WIDTH=3, expected_parameter_failure=True)]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def record_command(command, cwd, label, timeout=600):
    started = time.monotonic()
    log = cwd / (label + ".log")
    with log.open("w") as output:
        try:
            proc = subprocess.run(command, cwd=cwd, stdout=output, stderr=subprocess.STDOUT, timeout=timeout)
            code, timed_out = proc.returncode, False
        except subprocess.TimeoutExpired:
            code, timed_out = None, True
    result = dict(command=command, cwd=str(cwd), log=str(log), exit_code=code,
                  timeout=timed_out, elapsed_s=time.monotonic()-started)
    (cwd / (label + ".command.json")).write_text(json.dumps(result, indent=2) + "\n")
    return result


def simulate(run, case):
    work = run / "sim" / case["name"]
    work.mkdir(parents=True, exist_ok=False)
    records = []
    records.append(record_command(["xvlog", "-sv", str(URAM), str(LEAF), str(TB)], work, "compile"))
    if records[-1]["exit_code"] != 0:
        return dict(case=case, passed=False, failure_stage="compile", commands=records)
    generics = []
    for key, value in case.items():
        if key not in ["name", "expected_parameter_failure"]: generics += ["-generic_top", f"{key}={value}"]
    records.append(record_command(["xelab", "tb_smollm2_striped_weight_bank", "-L", "xpm", "-s", "bank_sim", "-timescale", "1ns/1ps"] + generics, work, "elaborate"))
    if records[-1]["exit_code"] != 0:
        return dict(case=case, passed=False, failure_stage="elaborate", commands=records)
    records.append(record_command(["xsim", "bank_sim", "-runall"], work, "simulate"))
    content = Path(records[-1]["log"]).read_text()
    marker = PASS_MARKER in [line.strip() for line in content.splitlines()]
    forbidden = re.search(r"(?m)^\s*(?:Fatal:|Error:|ERROR:)|CHECK_FAILED|timeout", content)
    parameter_failure = "Fatal: smollm2_striped_weight_bank illegal parameters" in content
    passed = records[-1]["exit_code"] == 0 and marker and not forbidden
    if case.get("expected_parameter_failure"):
        passed = records[-1]["exit_code"] in [0, 1] and parameter_failure and not marker
    counts = re.search(r"COUNTS checks=(\d+) reads=(\d+) writes=(\d+) cycles=(\d+)", content)
    return dict(case=case, passed=bool(passed), failure_stage=None if passed else "simulate",
                exact_pass_marker=marker, expected_parameter_failure_observed=parameter_failure, commands=records,
                counts=dict(zip(["checks", "reads", "writes", "cycles"], map(int, counts.groups()))) if counts else None)


def lint(run):
    work = run / "lint"
    work.mkdir()
    command = ["verilator", "--lint-only", "-Wall", "-DSYNTHESIS", "--top-module", "smollm2_striped_weight_bank",
               str(ROOT/"scripts/lint/declaration_lint.vlt"), str(ROOT/"scripts/lint/xpm_memory_sdpram.sv"), str(URAM), str(LEAF)]
    result = record_command(command, work, "leaf_strict_vendor_declaration")
    return dict(passed=result["exit_code"] == 0, source_mode="actual_leaf_and_uram_with_vendor_declaration_only", command=result,
                global_warning_suppressions=[], leaf_warning_suppressions=[],
                scoped_waivers=["Lint declaration only: UNUSEDPARAM, UNUSEDSIGNAL, UNDRIVEN", "Unmodified uram_bank line69: PINCONNECTEMPTY (unused ECC flags)",
                    "Lint declaration MEMORY_SIZE line7 only: WIDTHTRUNC; default2,097,152bits < signed32bit maximum2,147,483,647"],
                actual_vendor_lint="BLOCKED: Verilator5.020 unsupported vendor deassign; run001_lint preserved",
                note="Declaration stub has no behavior, and is excluded from actual XPM simulation and OOC synthesis.")


def synthesis(run):
    work = run / "ooc_work"
    work.mkdir()
    reports = run / "ooc_reports"
    result = record_command(["vivado", "-mode", "batch", "-source", str(ROOT / "scripts/striped_weight_bank_ooc.tcl"), "-tclargs", str(LEAF), str(URAM), str(reports)], work, "synthesis", timeout=1200)
    mapping = {}
    if (reports / "mapping.txt").exists():
        for line in (reports / "mapping.txt").read_text().splitlines():
            key, value = line.split("=", 1)
            if key != "uram_cell": mapping[key] = value
    exact_marker = 'PASS: smollm2 striped bank default-depth OOC mapping' in [line.strip() for line in Path(result["log"]).read_text().splitlines()]
    required = ["mapping.txt", "post_synth.dcp", "utilization.rpt", "utilization_hierarchical.rpt", "timing_summary.rpt", "setup_paths.rpt", "hold_paths.rpt", "clocks.rpt", "drc.rpt", "methodology.rpt", "exceptions.rpt"]
    missing = [name for name in required if not (reports/name).is_file() or (reports/name).stat().st_size == 0]
    return dict(passed=result["exit_code"] == 0 and exact_marker and not missing and mapping.get("blackbox_count") == "0" and int(mapping.get("uram288_count", "0")) > 0,
                stage="post_synthesis", part="xczu7ev-ffvc1156-2-e", clock_period_ns=5.0,
                parameters=dict(PORT_COUNT=4, PORT_DATA_WIDTH=128, DEPTH=16384, READ_LATENCY=3, ADDR_WIDTH=32),
                mapping=mapping, command=result, reports=str(reports), exact_pass_marker=exact_marker, missing_reports=missing,
                timing_gate="Report separately; synthesis completion is not timing closure.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--phase", choices=["sim", "lint", "ooc", "all"], default="all")
    parser.add_argument("--case", action="append", choices=[case["name"] for case in CASES], help="Run selected simulation cases only.")
    args = parser.parse_args()
    run = ROOT / "evidence/striped_weight_bank" / args.run_id
    run.mkdir(parents=True, exist_ok=False)
    assert digest(CONTRACT) == EXPECTED_CONTRACT_HASH, "frozen contract mismatch"
    contract = json.loads(CONTRACT.read_text())
    reference_resolution = []
    for reference in contract["source_references"]:
        declared = Path(reference["path"])
        if declared.is_absolute() and not declared.is_relative_to(REPO):
            # The user-provided reference repository remains read-only and is not relocated.
            resolved = declared
            assert resolved.is_file() and not resolved.is_symlink(), "regular source reference required"
        else:
            resolved = resolve_reference(declared, root=REPO,
                                         expected_sha256=reference["sha256"])
        assert digest(resolved) == reference["sha256"], "source reference mismatch"
        reference_resolution.append(dict(declared_path=str(declared), resolved_path=str(resolved),
                                         sha256=reference["sha256"]))
    protected = [Path(r["resolved_path"]) for r in reference_resolution] + [CONTRACT, ROOT/"modules/striped_weight_bank.json", ROOT/"target_selection.json", ROOT/"numeric_decisions_pending.json"]
    before = {str(path): digest(path) for path in protected}
    closure = [LEAF, URAM, TB, XPM, CONTRACT, Path(__file__), ROOT/"scripts/striped_bank_reference.py", ROOT/"scripts/striped_weight_bank_ooc.tcl",
               ROOT/"scripts/lint/declaration_lint.vlt", ROOT/"scripts/lint/xpm_memory_sdpram.sv",
               REPO/"scripts/infrastructure_sources.py", REPO/"ip/infrastructure/migration.json"]
    sources = {str(path): digest(path) for path in closure}
    (run/"source_manifest.json").write_text(json.dumps(dict(sources=sources, protected=before,
        source_reference_resolution=reference_resolution), indent=2) + "\n")
    snapshot = run/"source_snapshot"
    snapshot.mkdir()
    for path in closure: shutil.copyfile(path, snapshot/path.name)
    versions = {}
    for exe, option in [("vivado", "-version"), ("verilator", "--version")]:
        rec = record_command([exe, option], run, exe+"_version")
        versions[exe] = Path(rec["log"]).read_text().strip()
    results = dict(run_id=args.run_id, generated_utc=datetime.now(timezone.utc).isoformat(), scope="opaque_bank_leaf", phase=args.phase,
                   sources=sources, tools=versions, golden_reference=generate(run/"reference"),
                   source_reference_resolution=reference_resolution)
    if args.phase in ["sim", "all"]:
        results["simulation"] = [simulate(run, case) for case in CASES if not args.case or case["name"] in args.case]
    if args.phase in ["lint", "all"]: results["lint"] = lint(run)
    if args.phase in ["ooc", "all"]:
        earlier_passed = all(r["passed"] for r in results.get("simulation", [])) and results.get("lint", {}).get("passed", True)
        results["synthesis"] = synthesis(run) if earlier_passed else dict(passed=False, skipped=True, reason="earlier phase failed")
    after = {str(path): digest(path) for path in protected}
    results["protected_files_unchanged"] = before == after
    results["source_files_unchanged_during_run"] = sources == {str(path): digest(path) for path in closure}
    results["all_requested_phases_passed"] = (results["protected_files_unchanged"] and results["source_files_unchanged_during_run"]
        and all(r["passed"] for r in results.get("simulation", []))
        and results.get("lint", {}).get("passed", True) and results.get("synthesis", {}).get("passed", True))
    (run/"result.json").write_text(json.dumps(results, indent=2) + "\n")
    print(json.dumps(dict(run=str(run), passed=results["all_requested_phases_passed"], simulation=[r["passed"] for r in results.get("simulation", [])], lint=results.get("lint", {}).get("passed"), synthesis=results.get("synthesis", {}).get("passed")), indent=2))
    return 0 if results["all_requested_phases_passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
