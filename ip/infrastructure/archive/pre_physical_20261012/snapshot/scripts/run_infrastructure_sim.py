#!/usr/bin/env python3
"""Run fresh, source-identified infrastructure compilation and simulation checks."""
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
import traceback

from infrastructure_sources import ROOT, load_manifest, resolve_profile, validate_inventory


INFRA = ROOT / "ip/infrastructure"
XSIM_RUNNER = INFRA / "datamover_engine/scripts/run_xsimk.py"
BAD_MESSAGE = re.compile(r"(?<![A-Za-z0-9_])(?:Fatal|FATAL|ERROR)(?::|\b)")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2, default=str) + "\n", encoding="utf-8")


def decoded_xsim(transcript: str) -> str:
    """Decode actual simulator stdout records, excluding protocol/echo text."""
    messages = []
    for line in transcript.splitlines():
        if line.startswith("@"):
            value = json.loads(line[1:].strip())
            if not isinstance(value, str):
                raise ValueError("XSIM stdout record is not a JSON string")
            messages.append(value)
    return "".join(messages)


def run_command(command, cwd, log, env, timeout=120):
    command = [str(item) for item in command]
    started = time.monotonic()
    record = {"command": command, "cwd": str(cwd), "log": str(log),
              "timeout_seconds": timeout, "timed_out": False}
    with log.open("x", encoding="utf-8") as output:
        try:
            process = subprocess.Popen(command, cwd=cwd, env=env, stdout=output,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            try:
                process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                record["timed_out"] = True
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            record["exit_code"] = process.returncode
        except OSError as error:
            output.write(f"{type(error).__name__}: {error}\n")
            record["exit_code"] = 127
            record["error"] = str(error)
    record["duration_seconds"] = time.monotonic() - started
    text = log.read_text(encoding="utf-8", errors="replace")
    record["forbidden_diagnostic"] = bool(BAD_MESSAGE.search(text))
    record["passed"] = (record["exit_code"] == 0 and not record["timed_out"]
                        and not record["forbidden_diagnostic"])
    return record


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="fresh output directory")
    parser.add_argument("--suite", choices=("leaf", "integration", "all"), default="all")
    default_bin = os.environ.get("VIVADO_BIN")
    if default_bin is None:
        default_bin = str(Path(os.environ.get("XILINX_VIVADO", "/tools/Xilinx/2025.2/Vivado")) / "bin")
    parser.add_argument("--vivado-bin", type=Path, default=Path(default_bin))
    args = parser.parse_args()
    out = args.out.expanduser().resolve()
    if out.exists():
        parser.error(f"fresh output directory required: {out}")
    out.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    result = {"schema": "llm2rtl.infrastructure_sim.v1", "status": "running",
              "suite": args.suite, "started_utc": datetime.now(timezone.utc).isoformat(),
              "source_root": str(ROOT), "output_directory": str(out), "cases": [],
              "tool_versions": {}, "scope": "compilation and self-checking simulation only; "
              "no synthesis, timing, physical DDR/vendor DMA, or board signoff"}
    known_inputs = {}
    env = os.environ.copy()
    vivado_bin = args.vivado_bin.expanduser().resolve()
    env["XILINX_VIVADO"] = str(vivado_bin.parent)
    env["VIVADO_BIN"] = str(vivado_bin)
    result["tool_environment"] = {key: env[key] for key in ("XILINX_VIVADO", "VIVADO_BIN")}

    def inputs(paths):
        records = []
        for path in dict.fromkeys(paths):
            path = Path(path)
            if not path.is_absolute() or not path.is_file() or path.is_symlink():
                raise ValueError(f"original regular input required: {path}")
            sha = digest(path)
            if str(path) in known_inputs and known_inputs[str(path)] != sha:
                raise ValueError(f"input changed during run: {path}")
            known_inputs[str(path)] = sha
            records.append({"path": str(path), "sha256": sha,
                            "generated_fixture": path.is_relative_to(out)})
        return records

    def command(case, argv, name):
        record = run_command(argv, Path(case["work_directory"]),
                             Path(case["work_directory"]) / name, env)
        case["commands"].append(record)
        save(Path(case["work_directory"]) / "result.json", case)
        if not record["passed"]:
            raise RuntimeError(f"{name} failed: exit={record['exit_code']} "
                               f"timeout={record['timed_out']} diagnostic={record['forbidden_diagnostic']}")
        return Path(record["log"]).read_text(encoding="utf-8", errors="replace")

    def case_run(name, profile, top=None, tb=(), parameters=None, simulator="xsim",
                 marker=None, controller_fixture=False):
        work = out / name
        work.mkdir(exist_ok=False)
        case = {"name": name, "profile": profile, "top": top, "simulator": simulator,
                "parameters": parameters or {}, "expected_pass_line": marker,
                "work_directory": str(work), "status": "running", "commands": []}
        case_started = time.monotonic()
        try:
            sources = resolve_profile(profile, root=ROOT, manifest=manifest)
            extra_inputs = []
            if controller_fixture:
                helper = INFRA / "cmd_dispatcher_template/scripts/native_test_support.py"
                templates = [INFRA / "bank_subsystem_template/rtl" / name
                             for name in ("bank_config_pkg.sv.tpl", "bank_subsystem.sv.tpl")]
                extra_inputs = [helper, *templates]
                inputs(extra_inputs)
                spec = importlib.util.spec_from_file_location("native_controller_support", helper)
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                generated = module.materialize_banks(work)
                # Only its existing template outputs are used; real children come from the resolver.
                sources = [generated[0], *resolve_profile("native_bank_children", root=ROOT,
                           manifest=manifest), generated[-1], *sources]
            sources = list(dict.fromkeys(sources))
            tests = [INFRA / path for path in tb]
            case["sources"] = inputs(sources)
            case["testbenches"] = inputs(tests)
            case["additional_inputs"] = inputs(extra_inputs + ([XSIM_RUNNER] if simulator == "xsim" else []))
            save(work / "result.json", case)
            if simulator == "iverilog":
                compile_args = ["iverilog", "-g2012", "-s", top]
                compile_args += [f"-P{top}.{key}={value}" for key, value in case["parameters"].items()]
                command(case, [*compile_args, "-o", work / "simulation.vvp", *sources, *tests], "compile.log")
                transcript = command(case, ["vvp", work / "simulation.vvp"], "simulation.log")
                decoded = transcript
            else:
                command(case, [vivado_bin / "xvlog", "--sv", *sources, *tests], "compile.log")
                if simulator == "compile":
                    case["status"] = "passed"
                    case["coverage"] = "syntax/package compilation; not elaboration or function"
                    return
                snapshot = "infrastructure_sim"
                elaborate = [vivado_bin / "xelab", top, "-L", "xpm", "-s", snapshot,
                             "-timescale", "1ns/1ps"]
                for key, value in case["parameters"].items():
                    elaborate += ["-generic_top", f"{key}={value}"]
                command(case, elaborate, "elaborate.log")
                transcript = command(case, [sys.executable, XSIM_RUNNER,
                    work / "xsim.dir" / snapshot / "xsimk", marker], "simulation.log")
                decoded = decoded_xsim(transcript)
            (work / "simulation.stdout").write_text(decoded, encoding="utf-8")
            case["pass_line_count"] = decoded.splitlines().count(marker)
            case["decoded_forbidden_diagnostic"] = bool(BAD_MESSAGE.search(decoded))
            if case["pass_line_count"] != 1 or case["decoded_forbidden_diagnostic"]:
                raise RuntimeError("exact executed PASS line missing/duplicated or failure diagnostic found")
            case["status"] = "passed"
        except Exception as error:
            case["status"] = "failed"
            case["error"] = f"{type(error).__name__}: {error}"
            (work / "failure.txt").write_text(traceback.format_exc(), encoding="utf-8")
        finally:
            case["duration_seconds"] = time.monotonic() - case_started
            save(work / "result.json", case)
            result["cases"].append(case)
            save(out / "result.json", result)
            print(f"{case['status'].upper()} {name}", flush=True)

    try:
        manifest = load_manifest(root=ROOT)
        result["inventory_validation"] = validate_inventory(root=ROOT, manifest=manifest)
        save(out / "source_manifest.json", manifest)
        result["active_sources"] = inputs(resolve_profile("all", root=ROOT, manifest=manifest))
        result["runner_inputs"] = inputs([Path(__file__).resolve(), ROOT / "scripts/infrastructure_sources.py",
                                           ROOT / "ip/infrastructure/sources.json"])
        versions = [("vivado", [vivado_bin / "vivado", "-version"])]
        if args.suite in ("leaf", "all"):
            versions += [("iverilog", ["iverilog", "-V"]), ("vvp", ["vvp", "-V"])]
        for name, argv in versions:
            record = run_command(argv, out, out / f"version_{name}.log", env)
            record["output"] = (out / f"version_{name}.log").read_text(encoding="utf-8", errors="replace")
            result["tool_versions"][name] = record
        save(out / "result.json", result)

        if args.suite in ("leaf", "all"):
            for width in (32, 64, 128):
                case_run(f"mm2s_bank{width}", "adapters", "tb_mm2s_adapter",
                         ["datamover_engine/tb/tb_mm2s_adapter.sv"], {"BANK_WIDTH": width}, "iverilog",
                         f"PASS mm2s bank={width} packet-boundary/offset/tail/abort/rearm")
                for latency in (1, 3):
                    case_run(f"s2mm_bank{width}_lat{latency}", "adapters", "tb_s2mm_adapter",
                             ["datamover_engine/tb/tb_s2mm_adapter.sv"],
                             {"BANK_WIDTH": width, "READ_LAT": latency}, "iverilog",
                             f"PASS s2mm bank={width} stream=64 latency={latency} offset/tail/stall/abort/rearm")
            case_run("support", "support", "tb_support", ["datamover_engine/tb/tb_support.sv"],
                     simulator="iverilog", marker="PASS support FIFO non-power-of-two/full/simultaneous/wrap/reset")
            case_run("command_queue", "command_queue", "tb_command_queue",
                     ["datamover_engine/tb/tb_command_queue.sv"], simulator="iverilog",
                     marker="PASS command queue descriptor/order/capacity/tag-wrap/status-fault/stall/scheduler-recovery/abort-concurrency")
            tests = [
                ("stream_adapters", "stream_bank_adapters", "PASS stream_bank_adapters randomized stalls full partial abort reset repeated no_duplicate"),
                ("ownership", "bank_ownership_table", "PASS: bank_ownership_table verification cases=8"),
                ("port_router", "bank_port_router", "PASS: bank_port_router verification cases=11"),
                ("sparse_router", "bank_sparse_router", "PASS: bank_sparse_router verification cases=11"),
                ("dispatcher", "sparse_isa_dispatcher", "SPARSE_ISA_DISPATCHER_XSIM_PASS cases=19"),
            ]
            for profile, packet, marker in tests:
                case_run(profile, profile, f"tb_{packet}", [f"{packet}/tb/tb_{packet}.sv"], marker=marker)
            for latency, capability in ((1, 0), (2, 0), (2, 1)):
                case_run(f"controller_lat{latency}_cap{capability}", "controller", "tb_cmd_dispatcher_template",
                         ["cmd_dispatcher_template/tb/tb_cmd_dispatcher_template.sv"],
                         {"CMD_READ_LATENCY": latency, "CAPABILITY_CASE": capability},
                         marker="PASS: cmd_dispatcher_template native controller verification", controller_fixture=True)
            case_run("all_rtl_compile", "all", simulator="compile")

        if args.suite in ("integration", "all"):
            for width in (32, 128):
                for latency in (1, 3):
                    case_run(f"dma_bank{width}_lat{latency}", "dma_integration", "tb_engine_integration",
                             ["datamover_engine/tb/integration_bank.sv", "datamover_engine/tb/tb_engine_integration.sv"],
                             {"BANK_DATA_WIDTH": width, "BANK_READ_LAT": latency},
                             marker="PASS integration scheduler/engine/adapters/arbiter DDR-copy queued same-bank contention "
                             f"concurrency rejection fault scheduler-reset bank={width} latency={latency}")
            case_run("legacy_bank", "legacy_bank", "tb_bank_subsystem", ["bank_subsystem/tb/tb_bank_subsystem.sv"],
                     marker="BANK_SUBSYSTEM_XSIM_PASS cases=11 asymmetric_word={addr1,addr0}")
            case_run("legacy_fabric", "legacy_fabric", "tb_execution_fabric", ["execution_fabric/tb/tb_execution_fabric.sv"],
                     marker="EXECUTION_FABRIC_XSIM_PASS cases=3 payloads=ACT_WGT_OUT tag_identity=separate unsupported_traffic=none")
    except Exception as error:
        result["fatal_error"] = f"{type(error).__name__}: {error}"
        (out / "failure.txt").write_text(traceback.format_exc(), encoding="utf-8")
    finally:
        changes = []
        for name, sha in known_inputs.items():
            path = Path(name)
            if not path.is_file() or path.is_symlink() or digest(path) != sha:
                changes.append(name)
        result["changed_or_missing_inputs"] = changes
        try:
            if "manifest" in locals():
                result["final_inventory_validation"] = validate_inventory(root=ROOT, manifest=manifest)
        except Exception as error:
            result["final_inventory_error"] = f"{type(error).__name__}: {error}"
        result["passed_cases"] = sum(case["status"] == "passed" for case in result["cases"])
        result["failed_cases"] = sum(case["status"] != "passed" for case in result["cases"])
        result["status"] = "passed" if (result["cases"] and not result["failed_cases"] and not changes
            and not result.get("fatal_error") and not result.get("final_inventory_error")
            and all(record["passed"] for record in result["tool_versions"].values())) else "failed"
        result["duration_seconds"] = time.monotonic() - started
        result["finished_utc"] = datetime.now(timezone.utc).isoformat()
        save(out / "result.json", result)
    print(f"{result['status'].upper()} cases={result['passed_cases']}/{len(result['cases'])} result={out / 'result.json'}")
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
