#!/usr/bin/env python3
"""Sequential cold-start pilot; preserve evidence without judging self-reports."""
import argparse
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import random
import shutil
import signal
import subprocess
import time

STUDY = Path(__file__).resolve().parents[1]
REPO = STUDY.parents[1]
DEFAULT_STORAGE = Path("/media/admin1/backup/shmin/llm2rtl_experiments/cold_start_v1")
SANDBOX_SOURCE = STUDY / "scripts/sandbox_runtime.py"


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def save(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metrics(path):
    usage = {"input_tokens": 0, "cached_input_tokens": 0, "output_tokens": 0}
    tools = set()
    errors = []
    final = []
    for line in path.read_text(errors="replace").splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get("type") == "turn.completed":
            for name in usage:
                usage[name] += event.get("usage", {}).get(name, 0)
        if event.get("type") in ["error", "turn.failed"]:
            errors.append(event)
        item = event.get("item", {})
        if item.get("type") in ["command_execution", "mcp_tool_call"]:
            tools.add(item.get("id", repr(item)))
        if item.get("type") == "agent_message" and event.get("type") == "item.completed":
            final.append(item.get("text", ""))
    return {"usage": usage, "tool_item_count": len(tools), "errors": errors,
            "last_agent_message": final[-1] if final else None,
            "usd_cost": None, "independent_verification": "NOT_EVALUATED"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--storage", type=Path, default=DEFAULT_STORAGE)
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    root = args.storage.resolve()
    if root != DEFAULT_STORAGE or root.exists():
        raise SystemExit("requires a new, exact study storage directory")
    root.mkdir(parents=True)
    protocol = json.loads((STUDY / "protocol.json").read_text())
    save(root / "protocol_at_launch.json", protocol)
    shutil.copy2(Path(__file__), root / "supervisor_source.py")
    shutil.copy2(SANDBOX_SOURCE, root / "sandbox_source.py")
    spec = importlib.util.spec_from_file_location("frozen_sandbox", root / "sandbox_source.py")
    sandbox = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(sandbox)
    order = list(protocol["conditions"])
    random.Random(protocol["execution_order_seed"]).shuffle(order)
    save(root / "launch_manifest.json", {"created_utc": now(), "order": order,
        "protocol_sha256": sha(root / "protocol_at_launch.json"),
        "supervisor_sha256": sha(root / "supervisor_source.py"),
        "sandbox_sha256": sha(root / "sandbox_source.py")})
    common = '''HuggingFaceTB/SmolLM2-135M 모델의 FPGA 가속기를 설계하고 구현하라. 대상 보드는 ZCU104다.

This is a cold-start PILOT, excluded from main study statistics. You are a single
participant. All custom RTL, compute kernels, memory/control integration and host
execution programs must be generated from scratch in your workspace. No existing
accelerator implementation is supplied. Vendor IP and standard board documentation
may be used. Do not obtain pre-existing LLM accelerator source from any repository.
MANDATORY IMPLEMENTATION LANGUAGE: directly author synthesizable Verilog or
SystemVerilog for all model compute executors, control and integration RTL.
HLS is prohibited: do not use Vitis HLS, C/C++ synthesis, hls:: kernels, or other
high-level-to-RTL generators to implement model operations or execution control.
C/C++ and Python are allowed for host programs, packing, references and test drivers
only; these software programs must not replace RTL tensor execution. Standard vendor
infrastructure IP and leaf primitives are allowed, with explicit RTL integration.
Functional tensor tests must execute the real RTL datapath; C simulation or a
testbench that replaces arithmetic with software results is not RTL numeric proof.

Choose and document precision, quantization, accumulation, clock, parallelism,
memory layout, ISA or FSM, PS runtime and supported context/processing shapes.
You have delegated authority for all design choices; no user technical replies,
approval requests or continuation prompts will be provided. Do not load skills,
plugins, helper agents, prior conversations or other experiment workspaces.

Target full model prefill and continuous decode with persistent KV, with model
tensor execution in PL. PS/host may configure, transfer, generate commands,
tokenize and select tokens. They must not perform model tensor operations during
inference. Offline calibration, packing and test reference calculations are allowed.
Do not silently reduce the task to a single operation/layer or substitute a smaller
model. Report partial milestones honestly when the complete target remains unmet.

Model checkpoint is pinned for reproducibility at
/home/shmin/.cache/huggingface/hub/models--HuggingFaceTB--SmolLM2-135M/snapshots/93efa2f097d58c2a74874c7e644dbc9b0cee75a2
Python with torch/transformers: /home/shmin/.conda/envs/shmin/bin/python
Vivado/Vitis 2025.2 tool root: /media/admin1/backup/tools/Xilinx/2025.2
ZCU104 part: xczu7ev-ffvc1156-2-e. Physical board access is unavailable; prepare an
exact user-run handoff if feasible. Working directory: /home/shmin/workspace.

Resource policy, identical for both conditions: run only ONE heavyweight tool
process at a time. Use Vivado launch_runs -jobs 1 and set_param general.maxThreads 2;
limit BLAS/OpenMP/Torch CPU threads to 2. CPU affinity is limited to 8 cores by the
supervisor. These constraints manage shared-host resources, not RTL parallelism.

Your wall budget is 8 hours (28800 seconds), including implementation and tools.
Persist autonomously through functional failures; do not stop just to ask for
permission or say the next step. No enforced token cap applies in this pilot.
Create actual source and run real compile, numeric/state, integration and synthesis
checks. Distinguish simulation, synthesis, routed artifacts and physical FPGA proof.
Verification may use the pinned HF reference and independently generated fixtures.
Self-reported PASS is not an independently scored experiment result. The independent
evaluator is not a live feedback service in this initial cold-start pilot; use your
own diagnostic tests and preserve all raw evidence for later independent review.

Save DESIGN_SPEC.md with architectural decisions and supported scope, reproducible
build/test commands, source/artifact identities, and FINAL_REPORT.md with actual
completed gates and concrete remaining failures. Preserve actual failed test logs.
Do not fabricate artifacts, numerical comparisons or measured performance.
'''
    for condition in order:
        case = root / condition
        work = case / "workspace"
        work.mkdir(parents=True)
        provided = []
        addition = "\nGeneral Agent condition: choose your own design and verification procedure.\n"
        if condition == "llm2rtl_procedure":
            materials = [REPO / "README.md", REPO / "docs/framework_workflow.md",
                         REPO / "docs/isa_model_lowering.md"]
            materials += sorted((REPO / "contracts/common").glob("*.json"))
            for source in materials:
                target = work / "framework" / source.relative_to(REPO)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
                provided.append({"path": str(target.relative_to(work)), "sha256": sha(target)})
            addition = '''
LLM2RTL procedure condition: use the current documents and contracts in framework/.
Source implementations/templates mentioned by these documents are NOT supplied in
this strict cold-start experiment: write all custom RTL yourself. Apply operation
coverage, ISA/interpreter state checks, common command/completion and bank ownership
contracts, independent kernel tests and cumulative integration. The document steps
that normally discuss choices with a user are replaced by your delegated decisions:
record evidence and choices yourself, then proceed without requesting approval.
Physical board checks remain unperformed; complete feasible software/RTL/build gates
and clearly mark the hardware endpoint pending. Do not invoke old FPGA/LLM2RTL skills.
'''
        save(case / "provided_manifest.json", provided)
        (case / "initial_brief.txt").write_text(common + addition)
        if list(work.rglob("*.sv")) or list(work.rglob("*.v")):
            raise RuntimeError("cold start contaminated by supplied RTL")
    save(root / "supervisor_status.json", {"stage": "PREPARED", "updated_utc": now(),
        "order": order, "pilot": True, "main_runs_started": 0})
    if args.prepare_only:
        return
    for condition in order:
        case = root / condition
        work = case / "workspace"
        env = dict(os.environ)
        env["PATH"] = "/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin:" + env.get("PATH", "")
        command = sandbox.argv(work)
        if (work / "framework").exists():
            command += ["--ro-bind", str(work / "framework"), "/home/shmin/workspace/framework"]
        command += ["--", "/home/shmin/study_tools/codex", "exec", "--ephemeral",
                    "--ignore-user-config", "--skip-git-repo-check", "--approve-for-me",
                    "--json", "-m", protocol["participant_model"], "-c",
                    'model_reasoning_effort="' + protocol["reasoning"] + '"',
                    "-C", "/home/shmin/workspace", "-"]
        start = time.monotonic()
        with (case / "initial_brief.txt").open("rb") as brief, (case / "events.jsonl").open("wb") as log:
            process = subprocess.Popen(command, env=env, stdin=brief, stdout=log,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            save(case / "status.json", {"stage": "RUNNING", "started_utc": now(),
                "pid": process.pid, "budget_seconds": protocol["wall_budget_seconds"],
                "independent_verification": "NOT_EVALUATED"})
            save(root / "supervisor_status.json", {"stage": "RUNNING", "condition": condition,
                "updated_utc": now(), "main_runs_started": 0})
            timed_out = False
            try:
                process.wait(timeout=protocol["wall_budget_seconds"])
            except subprocess.TimeoutExpired:
                timed_out = True
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
        result = metrics(case / "events.jsonl")
        save(case / "metrics.json", result)
        save(case / "status.json", {"stage": "TIMEOUT" if timed_out else "PARTICIPANT_ENDED_REVIEW_REQUIRED",
            "finished_utc": now(), "elapsed_seconds": time.monotonic() - start,
            "exit_code": process.returncode, "independent_verification": "NOT_EVALUATED"})
        print(condition, "ENDED", process.returncode, flush=True)
        if process.returncode and not timed_out:
            save(root / "supervisor_status.json", {"stage": "STOPPED_EXECUTION_ERROR",
                 "condition": condition, "updated_utc": now(), "review_required": True})
            return
    save(root / "supervisor_status.json", {"stage": "PILOT_PARTICIPANTS_ENDED_REVIEW_REQUIRED",
        "updated_utc": now(), "main_runs_started": 0,
        "independent_verification": "NOT_EVALUATED"})


if __name__ == "__main__":
    main()
