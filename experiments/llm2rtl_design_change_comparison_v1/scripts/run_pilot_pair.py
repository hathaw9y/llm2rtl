#!/usr/bin/env python3
"""Supervise fresh, sequential unassisted pilot sessions; never patch candidates."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import random
import shutil
import signal
import subprocess
import time

STUDY = Path(__file__).resolve().parents[1]
CLI = '/home/shmin/.local/bin/codex'
PYTHON = '/home/shmin/.conda/envs/shmin/bin/python'
VIVADO = '/media/admin1/backup/tools/Xilinx/2025.2/Vivado/bin'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def save(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n')

def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()

def brief(task, condition):
    protocol = json.loads((STUDY / 'protocol.json').read_text())
    spec = next(t for t in protocol['tasks'] if t['id'] == task)
    asset_supplement = (STUDY / 'evaluator/t02/PUBLIC_ASSET_REGIONS_v2.md').read_text() if task == 'T02' else ''
    common = f'''You are a participant in a PILOT, excluded from main study results.
Implement this existing FPGA accelerator design change in your current workspace.
Task specification:\n{json.dumps(spec, indent=2)}
Common completion gates:\n{json.dumps(protocol['common_completion_gates'], indent=2)}
Public acceptance criteria:\n{(STUDY / 'evaluator' / task.lower() / 'PUBLIC.md').read_text()}
{asset_supplement}

Resources: the current workspace is an independent copy of the same baseline.
Both conditions receive all existing contracts, docs, interpreter and source.
Use Vivado/Vitis 2025.2, xczu7ev-ffvc1156-2-e, 100MHz.
Vivado binaries: {VIVADO}. Python with torch/transformers: {PYTHON}.
The fixed checkpoint is cached locally under /home/shmin/.cache/huggingface.
Tools and cached checkpoint reads outside the workspace are allowed.
Use only this workspace for design changes, tests, logs and build outputs.
Do not read other trial workspaces, supervisor files, the original repository,
study evaluator code/fixtures/results, or previous conversations.
Do not load old repository or installed llm2rtl/FPGA skills. Current repository
documents and contracts, and this brief, govern this experiment.
Do not run helper agents: this pilot uses one agent per session in both conditions.
PS must not compute model tensors. Offline weight packing and test comparison are
allowed; model tensor execution remains PL.

You have up to 90 minutes wall time from session launch, including your tool runs.
There is no enforced token cap in this pilot; token usage is recorded afterwards.
No human technical help or continuation prompts will follow. Make explicit
assumptions for unspecified reversible choices and complete the task autonomously.
Create and run your own public diagnostic tests against the stated criteria.
In this pilot the supervisor runs frozen independent public and hidden tests only
after your session ends; no live evaluator feedback service is provided to either
condition. Do not claim independent test or board PASS from your own reports.
Stop when implementation and feasible verification are complete, or clearly
report the concrete outstanding failure. Save a final report as PILOT_REPORT.md
with changed files, actual commands/results, source identity and remaining gates.
The supervisor independently judges source, not your success declaration.
'''
    workflow = '''
LLM2RTL condition procedure (the only condition-specific addition):
1. Review current contracts; identify operation, command, tensor/state and module
   boundaries affected by this change. Record invariants before implementation.
2. Update lowering/encoding and interpreter and check semantic/state equivalence
   before implementing changed RTL.
3. Implement the bounded modules and verify each against golden and common
   command/completion contracts, including errors and bank release.
4. Integrate cumulatively with all affected modes and compare full tensor states.
5. Run synthesis/resource/timing gates and publish matched source/evidence.
On test failure, inspect raw logs, repair the earliest broken contract and rerun
affected gates. Advance automatically when a stage passes; never wait for approval.
'''
    return common + (workflow if condition == 'llm2rtl' else
                     '\nGeneral Agent condition: choose your own implementation and verification workflow.\n')

def metrics(log):
    usage = {'input_tokens': 0, 'cached_input_tokens': 0, 'output_tokens': 0}
    tool_items = set()
    violations = []
    for line in log.read_text(errors='replace').splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get('type') == 'turn.completed':
            for k in usage:
                usage[k] += event.get('usage', {}).get(k, 0)
        item = event.get('item', {})
        if item.get('type') in ('command_execution', 'mcp_tool_call'):
            tool_items.add(item.get('id', json.dumps(item, sort_keys=True)))
            command = item.get('command', '')
            if '/home/shmin/llm2rtl' in command or '/evaluator/' in command:
                violations.append({'item_id': item.get('id'), 'command': command})
    return {'usage': usage, 'tool_item_count': len(tool_items),
            'possible_resource_scope_violations': violations,
            'scope_audit_limit': 'String audit is not OS-enforced secrecy; manual audit required.',
            'api_usd': None, 'cost_note': 'No attributable API dollar charge exposed by this runner.'}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--storage', type=Path, required=True)
    parser.add_argument('--task', choices=['T01', 'T02', 'T03'], required=True)
    args = parser.parse_args()
    manifest_path = args.storage / 'baseline_manifest.json'
    manifest = json.loads(manifest_path.read_text())
    baseline = args.storage / 'baseline'
    for row in manifest['files']:
        if digest(baseline / row['path']) != row['sha256']:
            raise RuntimeError('Baseline integrity mismatch: ' + row['path'])
    pair = args.storage / 'pilot' / args.task
    pair.mkdir(parents=True, exist_ok=False)
    shutil.copy2(STUDY / 'protocol.json', pair / 'protocol_at_launch.json')
    conditions = ['general_agent', 'llm2rtl']
    random.Random(20261006 + int(args.task[1:])).shuffle(conditions)
    save(pair / 'pair_plan.json', {
        'created_utc': now(), 'task': args.task, 'order': conditions,
        'purpose': 'pilot only; excluded from main18', 'wall_limit_seconds': 5400,
        'model': 'gpt-6.1-sol', 'reasoning': 'medium',
        'baseline_manifest_sha256': digest(manifest_path),
        'protocol_sha256': digest(STUDY / 'protocol.json'),
        'extra_human_technical_interventions_allowed': 0,
        'sequential_execution': True, 'live_public_evaluator_feedback': False,
        'hidden_access_control': 'Initial scope restriction and log audit, not OS-enforced read isolation.',
        'formal_all_gates_success': 'Requires additional independent common integration/synthesis gates; isolated task PASS alone is insufficient.'})
    prompts = {condition: brief(args.task, condition) for condition in conditions}
    save(pair / 'initial_briefs.json', prompts)
    shutil.copy2(Path(__file__), pair / 'supervisor_source.py')
    for condition in conditions:
        trial = pair / condition
        trial.mkdir()
        candidate = trial / 'candidate'
        shutil.copytree(baseline, candidate)
        # Plain copies, never editable hard links to the frozen baseline.
        prompt = prompts[condition]
        (trial / 'initial_brief.txt').write_text(prompt)
        metadata = {'task': args.task, 'condition': condition, 'status': 'RUNNING',
                    'started_utc': now(), 'initial_brief_sha256': digest(trial / 'initial_brief.txt'),
                    'expert_guidance_count': 0, 'expert_source_edits': 0,
                    'infra_permission_events': 'Retained in participant tool events; audit separately.'}
        save(trial / 'status.json', metadata)
        command = [CLI, 'exec', '--ephemeral', '--ignore-user-config',
                   '--skip-git-repo-check', '--approve-for-me', '--json',
                   '-m', 'gpt-6.1-sol', '-c', 'model_reasoning_effort="medium"',
                   '-C', str(candidate), '-']
        env = os.environ.copy()
        env['PATH'] = VIVADO + ':' + env.get('PATH', '')
        env['TMPDIR'] = str(candidate / 'tmp')
        (candidate / 'tmp').mkdir()
        started = time.monotonic()
        with (trial / 'events.jsonl').open('w') as stdout, (trial / 'stderr.log').open('w') as stderr:
            proc = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=stdout,
                                    stderr=stderr, env=env, start_new_session=True)
            try:
                proc.communicate(prompt.encode(), timeout=5400)
                metadata['status'] = 'PARTICIPANT_ENDED' if proc.returncode == 0 else 'RUNNER_ERROR'
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGTERM)
                try:
                    proc.wait(timeout=20)
                except subprocess.TimeoutExpired:
                    os.killpg(proc.pid, signal.SIGKILL)
                    proc.wait()
                metadata['status'] = 'BUDGET_EXHAUSTED'
        metadata.update(ended_utc=now(), elapsed_seconds=time.monotonic()-started,
                        exit_code=proc.returncode, **metrics(trial / 'events.jsonl'))
        changes = []
        for row in manifest['files']:
            file = candidate / row['path']
            after = digest(file) if file.exists() else None
            if after != row['sha256']:
                changes.append({'path': row['path'], 'before': row['sha256'], 'after': after})
        save(trial / 'changed_baseline_files.json', changes)
        save(trial / 'status.json', metadata)
        if args.task in ('T01', 'T02', 'T03'):
            results = {}
            for phase in ['public', 'hidden']:
                out = trial / ('evaluation_' + phase)
                with (trial / ('evaluator_' + phase + '.log')).open('w') as log:
                    try:
                        eval_command = [PYTHON, str(STUDY / f'scripts/{args.task.lower()}_evaluate.py'),
                                        '--candidate-root', str(candidate), '--out', str(out)]
                        if args.task == 'T01':
                            eval_command += ['--suite', phase]
                            if phase == 'public':
                                eval_command += ['--structural']
                        else:
                            eval_command += ['--split' if args.task == 'T02' else '--phase', phase]
                            if args.task == 'T02':
                                eval_command += ['--rtl']
                        result = subprocess.run(eval_command, stdout=log, stderr=subprocess.STDOUT,
                                                timeout=2400, env=env)
                        results[phase] = {'exit_code': result.returncode,
                                         'report': str(out / 'result.json')}
                    except subprocess.TimeoutExpired:
                        results[phase] = {'status': 'EVALUATOR_TIMEOUT; review infrastructure separately'}
            metadata['independent_task_evaluation'] = results
            if args.task == 'T02':
                asset_out = trial / 'evaluation_static_assets'
                with (trial / 'evaluator_static_assets.log').open('w') as log:
                    asset_result = subprocess.run(
                        [PYTHON, str(STUDY / 'scripts/t02_audit_assets.py'),
                         '--candidate-root', str(candidate), '--out', str(asset_out),
                         '--reference-image', str(baseline / 'designs/smollm2_135m_bf16_zcu104_r1/full_model_board_probe/ddr_static_bf16.bin'),
                         '--reference-map', str(STUDY / 'evaluator/t02/static_reference_v2/reference_map_v2.json')],
                        stdout=log, stderr=subprocess.STDOUT, timeout=900)
                metadata['independent_static_asset_evaluation'] = {
                    'exit_code': asset_result.returncode,
                    'report': str(asset_out / 'asset_report.json')}
        metadata['common_all_gates'] = 'PENDING independent synthesis/integration/ABI/full-model review; not an all-gates PASS'
        save(trial / 'status.json', metadata)
        print(json.dumps(metadata), flush=True)
    save(pair / 'supervisor_status.json', {'status': 'PAIR_FINISHED', 'ended_utc': now()})

if __name__ == '__main__':
    main()
