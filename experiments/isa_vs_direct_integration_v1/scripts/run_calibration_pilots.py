#!/usr/bin/env python3
"""Launch clean isolated integration pilots, never infer PASS from agent reports."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import time

STUDY = Path(__file__).resolve().parents[1]
REPO = STUDY.parents[1]
DESIGN = REPO / 'designs/smollm2_135m_bf16_zcu104_r1'
STORAGE = Path('/media/admin1/backup/shmin/llm2rtl_experiments/isa_vs_direct_v1')


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + '.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def manifest(root):
    return [{'file': str(p.relative_to(root)), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest(),
             'bytes': p.stat().st_size} for p in sorted(root.rglob('*')) if p.is_file()]


def brief(task, condition, protocol):
    text = f'''You are a single participant in a CALIBRATION PILOT, excluded from formal study results.
Implement task {task['id']} from scratch using the supplied immutable standalone kernels.
Task: {json.dumps(task)}
Hardware: {json.dumps(protocol['hardware'])}
Model: {json.dumps(protocol['model'])}

Implementation language: directly authored synthesizable Verilog/SystemVerilog
for new control and integration. HLS and other high-level-to-RTL synthesis are
prohibited. Python/C/C++ are for host control, packing, offline reference and tests.
Resource policy (identical for both arms): run ONE heavyweight synthesis/simulation
process at a time; Vivado launch_runs -jobs 1 and set_param general.maxThreads 2.
Keep BLAS/OpenMP/Torch CPU threads <=2. The supervisor limits CPU affinity to 8
cores. This is infrastructure policy, not a design or debugging hint.

Both arms receive exactly the same kernels, native-call ABI, numerical information,
checkpoint, HF reference tensors, tools, budgets and this common specification.
No finished dispatcher, controller, integration fabric or model instruction program
is provided. Create control and wiring RTL and a host execution program yourself.
Use exactly ONE smollm2_gemm_systolic_wide_executor (256 PEs) shared across every
matrix operation in this task. Immutable kernels must actually compute outputs.
PS/host may pack weights, transfer data, generate control/programs and check tests;
it must not compute model tensors during accelerator execution. Offline oracle
and test vector generation is allowed. No hidden alternate compute datapath.

Required workload: layer0 BF16, H576, FFN1536, 9 query / 3 KV heads, head dimension64.
Support processing M1..32, contiguous positions, causal masking, context<=1024.
I01 outputs full Q-after-RoPE, K-after-RoPE, V. I02 receives Q/new K/new V and prior
KV, appends once and computes full context. I03 executes the full decoder block,
including the two residual adds and FFN, and returns full hidden and updated KV.
For I02/I03 support prefill followed by at least four teacher-forced decode calls
WITHOUT reset. Preserve the old KV prefix and compare all channels. Independent
jobs reset explicitly. No arbitrary padding masks or user-selected position IDs.

Memory conditions shared between arms: external DDR holds weight tiles and KV;
compute calls use logical local banks and native bank-port ABI. Implement routing,
bank ownership and bank adapters yourself. A single read response per accepted
read is returned with data and bank ID; hold control/data stable when not ready.
Match native 128-bit word addresses and 256-bit GEMM source accesses. Bank limits
and native call payloads are documented in kernel_contracts.json. Standalone
kernel sources are authoritative for native bank-role restrictions and arithmetic.
DMA may use a common abstract external service in simulation: descriptor valid/ready,
DDR address, local bank, byte count, direction; identified completion/error only
after the last memory write. Specify this interface and implement synthesizable
local control; a simulation service is not FPGA deployment evidence. Never silently
mark a DMA complete at descriptor acceptance. No bank release before matching
kernel completion; do not overwrite live tensors. Read response latency and write
and completion backpressure must be exercised, not just always-ready tests.

Provide a uniform job API for rows, contiguous starting position, prior KV length,
DDR input/weights/KV/output addresses, start/ready and held identified done/error.
Each arm may choose its physical job port representation and must document it.
The evaluator will use an adapter around it; implementing an adapter is part of
the work. I01 has no persistent KV update. Use semantic_reference/ as HF reference
only, NOT a bit-exact oracle for the supplied custom RTL arithmetic. Kernel GEMM
accumulation is a signed32 significand with a separate exponent, not IEEE FP32.
Create tests for integration that respect the actual arithmetic and BF16 casts.

Deliver:
1. Synthesizable control and wiring RTL under rtl/, an explicit full-source manifest,
   top module, clock constraint (100MHz, xczu7ev-ffvc1156-2-e), and build instructions.
2. Executable Python host program that creates the chosen execution control inputs.
3. A self-checking integration runner accepting --cases JSON --out DIRECTORY; define
   its public JSON input/result schema so a separate evaluator can adapt to it.
4. Timestamp and source hash of the FIRST actual-kernel numerical integration test,
   preserving compile/elaboration/numerical failures and all later revision results.
5. Full tensor comparisons, KV-prefix checks when applicable, error/bounds tests,
   shared GEMM instance/PE count, cycle measurements, and feasible full-top synthesis.
   Synthesis memory models must be distinguished from synthesizable local banks;
   no unresolved black boxes or unconstrained internal clocks count as synthesis PASS.
6. PILOT_REPORT.md with actual commands, results, remaining failures and source hashes.

This is calibration: the fixed integration arithmetic oracle and independent adapter
are not yet qualified. Your self-test is NOT independent acceptance. Do not invent
hidden-test PASS, FPGA PASS, or formal completion. Evaluator deficiencies will be
recorded separately after participant completion and this run stays out of main18.
Initial requirements are fixed for this session; no subsequent design hints will
be supplied. Work autonomously and make reversible choices with written reasons.
Do not request progress approval. Do not spawn helpers or load any skills.
Do not read prior trial directories, study/evaluator files or original repository.

Tools: /media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin;
Python /home/shmin/.conda/envs/shmin/bin/python has torch/transformers.
Checkpoint is cached locally. All outputs/builds stay in /home/shmin/workspace.
Budget: 90 minutes wall time INCLUDING your commands and self-tests. No enforced
token ceiling in this calibration; usage and tool counts are recorded. Complete
all feasible implementation/verification or report concrete remaining gaps.
'''
    if condition == 'isa':
        text += '''\nISA arm: define real instructions and generate an execution program. Implement
lowering and a Python instruction interpreter for tensor/state semantics before
RTL integration; implement instruction fetch/decode/dispatch and completion tracking.
The runtime program must control DMA, kernel sequencing, bank lifetime and terminal
completion. Preserve bank/KV across program segments. A separate task FSM or host
tensor compute must not bypass instruction execution. Document opcode semantics,
operands, tensor state transitions, numerical boundaries and interpreter comparisons.
'''
    else:
        text += '''\nDirect FSM arm: implement operation sequencing, address/tile counters, dependencies
and completion using RTL FSM/counters, with a host program supplying job parameters
and transfers. No programmable instruction memory/PC/opcode-fetch interpreter for
whole-task execution. Native cmd_valid/cmd_ready/cmd_opcode calls into immutable
kernels are permitted local module ABI, as are counters, constant kernel mode values,
software reference and testbenches. Choose your own implementation/validation order.
'''
    return text


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--run-id', default='calibration_001')
    a = p.parse_args()
    root = STORAGE / a.run_id
    root.mkdir(parents=True, exist_ok=False)
    protocol = json.loads((STUDY / 'protocol.json').read_text())
    save(root / 'protocol_at_launch.json', protocol)
    shutil.copyfile(__file__, root / 'supervisor_source.py')
    inventory = json.loads((STUDY / 'kernel_inventory.json').read_text())
    # Materialize all briefs and immutable inputs BEFORE launching either arm.
    order = [('I01', 'isa'), ('I01', 'direct_fsm'), ('I02', 'direct_fsm'),
             ('I02', 'isa'), ('I03', 'isa'), ('I03', 'direct_fsm')]
    save(root / 'launch_plan.json', {'order': order, 'main_runs_started': False,
        'excluded_from_main': True, 'independent_evaluator_ready': False,
        'ordering': 'fixed alternating calibration order, not randomized formal order'})
    for task_id, condition in order:
        task = next(t for t in protocol['tasks'] if t['id'] == task_id)
        trial = root / task_id / condition
        workspace = trial / 'candidate'
        (workspace / 'kernels').mkdir(parents=True)
        for entry in inventory['files']:
            src = REPO / entry['origin']
            if hashlib.sha256(src.read_bytes()).hexdigest() != entry['sha256']:
                raise RuntimeError('kernel identity changed: ' + str(src))
            shutil.copyfile(src, workspace / 'kernels' / entry['file'])
        contracts = {}
        for name in ['gemm_executor', 'rmsnorm_executor', 'rope_executor',
                     'softmax_executor', 'silu_mul_executor', 'add_executor']:
            source = DESIGN / 'modules' / (name + '.json')
            if source.exists():
                value = json.loads(source.read_text())
                contracts[name] = {key: value[key] for key in ['interface', 'numeric', 'architecture'] if key in value}
        save(workspace / 'kernel_contracts.json', contracts)
        shutil.copytree(STORAGE / 'reference/semantic_run001', workspace / 'semantic_reference')
        save(trial / 'initial_manifest.json', manifest(workspace))
        (trial / 'initial_brief.txt').write_text(brief(task, condition, protocol))
        save(trial / 'status.json', {'status': 'QUEUED', 'task': task_id, 'condition': condition})
    isolation = STUDY / 'scripts/isolate_participant.py'
    for index, (task_id, condition) in enumerate(order):
        trial = root / task_id / condition
        workspace = trial / 'candidate'
        probe = subprocess.run(['python3', str(isolation), '--workspace', str(workspace), '--check-only'],
                               capture_output=True, text=True)
        (trial / 'isolation_probe.log').write_text(probe.stdout + probe.stderr)
        if probe.returncode:
            save(root / 'status.json', {'stage': 'INFRASTRUCTURE_FAILURE', 'error': 'isolation probe', 'trial': str(trial)})
            raise SystemExit(1)
        save(root / 'status.json', {'stage': 'PARTICIPANT_RUNNING', 'current_task': task_id,
            'current_condition': condition, 'participants_started': index+1,
            'participants_ended': index, 'main_runs_started': False, 'updated_utc': now()})
        start = time.monotonic()
        save(trial / 'status.json', {'status': 'RUNNING', 'started_utc': now(), 'task': task_id, 'condition': condition})
        command = ['python3', str(isolation), '--workspace', str(workspace),
                   '--brief', str(trial / 'initial_brief.txt'), '--log', str(trial / 'events.jsonl')]
        with (trial / 'supervisor_stderr.log').open('w') as err:
            child = subprocess.Popen(command, stdout=err, stderr=err, start_new_session=True)
            try:
                code = child.wait(timeout=5400)
                status = 'PARTICIPANT_ENDED' if code == 0 else 'PARTICIPANT_PROCESS_ERROR'
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGTERM)
                try:
                    child.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGKILL)
                    child.wait()
                code = child.returncode
                status = 'TIMEOUT'
        save(trial / 'status.json', {'status': status, 'exit_code': code,
            'elapsed_seconds': time.monotonic()-start, 'ended_utc': now(),
            'independent_acceptance': 'NOT_RUN', 'task': task_id, 'condition': condition})
        if status == 'PARTICIPANT_PROCESS_ERROR':
            save(root / 'status.json', {'stage': 'STOPPED_EXECUTION_ERROR',
                'task': task_id, 'condition': condition, 'exit_code': code,
                'updated_utc': now(), 'review_required': True})
            raise SystemExit(1)
    save(root / 'status.json', {'stage': 'PARTICIPANT_SESSIONS_ENDED_EVALUATION_PENDING',
         'participants_started': 6, 'participants_ended': 6, 'main_runs_started': False,
         'independent_acceptance': 'NOT_RUN', 'updated_utc': now()})


if __name__ == '__main__':
    main()
